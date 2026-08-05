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

'' ------------------------------------------------- PRINT USING
''
'' FIELD WIDTHS COUNT CODE UNITS, not bytes. That is the whole reason
'' fb_PrintUsingUStr parses in UTF-16 instead of converting to UTF-8 and
'' delegating to fb_PrintUsingStr: a byte-counting field would slice "héllo"
'' after "hél", and only when the output happened to be redirected.

#macro chkusg( nm, fmt, arg, want )
    scope
        dim as integer uf = freefile
        open TMPF for output as #uf
        print #uf, using fmt; arg;
        close #uf
        dim as integer ug = freefile
        dim as ustring ur
        open TMPF for input as #ug
        line input #ug, ur
        close #ug
        chks( nm, ur, want )
    end scope
#endmacro

dim as ustring pu = "héllo"
chkusg( "USING exact field",     "[\   \]", pu, "[héllo]" )
chkusg( "USING counts units",    "[\  \]",  pu, "[héll]" )
chkusg( "USING pads short",      "[\      \]", pu, "[héllo   ]" )
chkusg( "USING ! is one unit",   "[!]",      pu, "[h]" )
chkusg( "USING & is whole",      "[&]",      pu, "[héllo]" )

'' A surrogate pair is 2 units, so a 3-unit field holds "a" plus the pair
'' whole, and a 2-unit field splits it -- exactly as MID does. Splitting is a
'' property of UTF-16, not of PRINT USING.
dim as ustring pm = "a" + wchr(&h1D11E) + "b"
chk   ( "astral arg is 4 units", len(pm), 4 )
chkusg( "USING keeps pair whole", "[\ \]", pm, "[a" + wchr(&h1D11E) + "]" )

'' A USTRING * N argument, and a USTRING used AS the format string
dim as ustring * 8 pf = "world"
chkusg( "USING fixed-length arg", "[\   \]", pf, "[world]" )
dim as ustring pfmt = "<\   \>"
chkusg( "USING ustring format",   pfmt, pu, "<héllo>" )

kill TMPF

print g_run; " checks,"; g_fail; " failed"
if( g_fail <> 0 ) then end 1