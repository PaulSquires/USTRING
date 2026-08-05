'' Phase 5: I/O for USTRING.
''
'' THE RULE: where the output goes decides the encoding. A real Windows
'' console takes the wide path so the OS renders UTF-16 directly; everything
'' else -- files, redirected output, non-Windows consoles -- gets UTF-8.
''
'' That second half is the point. A ustring written to a file must produce a
'' portable file on every platform. The existing wstring path writes raw
'' UTF-16 bytes when redirected, which no other tool reads as text.

dim shared as integer g_run, g_fail
sub chk( byref nm as string, byval got as longint, byval want as longint )
    g_run += 1
    if( got <> want ) then
        g_fail += 1
        print "FAIL "; nm; " got="; got; " want="; want
    end if
end sub
sub chks( byref nm as string, byref got as ustring, byref want as ustring )
    g_run += 1
    if( got <> want ) then
        g_fail += 1
        dim as string a, b : a = got : b = want
        print "FAIL "; nm; " got=["; a; "] want=["; b; "]"
    end if
end sub

const TMPF = "ustring_io_tmp.txt"

'' ---------------------------------------------- PRINT # writes UTF-8
dim as ustring w1 = "héllo €"
dim as ustring w2 = "astral: 𝄞"

dim as integer f = freefile
open TMPF for output as #f
print #f, w1
print #f, w2
close #f

'' read the raw bytes back and confirm they really are UTF-8
dim as string raw
f = freefile
open TMPF for binary as #f
raw = space(lof(f))
get #f, , raw
close #f

'' h C3 A9 l l o SP E2 82 AC  -- the accented e and the euro sign as UTF-8
chk( "file byte 1 is h", asc(mid(raw,1,1)), 104 )
chk( "U+00E9 first byte", asc(mid(raw,2,1)), 195 )
chk( "U+00E9 second byte", asc(mid(raw,3,1)), 169 )
chk( "byte 7 is the space", asc(mid(raw,7,1)), 32 )
chk( "U+20AC lead byte", asc(mid(raw,8,1)), 226 )

'' the astral character must be 4 UTF-8 bytes, not a surrogate pair on disk
chk( "astral encodes to 4 bytes", instr(raw, chr(240) + chr(157) + chr(132) + chr(158)) > 0, -1 )

'' ------------------------------------------- LINE INPUT # round-trip
dim as ustring r1, r2
f = freefile
open TMPF for input as #f
line input #f, r1
line input #f, r2
close #f

chks( "line 1 round-trips", r1, w1 )
chks( "line 2 round-trips", r2, w2 )
chk ( "line 1 is 7 code units", len(r1), 7 )
chk ( "astral line is 2 units for the char", len(r2), len("astral: ") + 2 )

'' ------------------------------------------------------ INPUT #
f = freefile
open TMPF for output as #f
print #f, "alpha"
print #f, "bêta"
close #f

dim as ustring i1, i2
f = freefile
open TMPF for input as #f
input #f, i1
input #f, i2
close #f
chks( "INPUT # first", i1, "alpha" )
chks( "INPUT # second", i2, "bêta" )

'' ------------------------------------------------------ WRITE #
f = freefile
open TMPF for output as #f
write #f, w1
close #f
f = freefile
open TMPF for input as #f
dim as ustring q
line input #f, q
close #f
'' WRITE quotes its output
chks( "WRITE # quotes", q, """" + w1 + """" )

kill TMPF

print g_run; " checks,"; g_fail; " failed"
if( g_fail <> 0 ) then end 1