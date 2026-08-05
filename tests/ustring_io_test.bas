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

'' --------------------------------------------- OPEN ... ENCODING
''
'' This was DOUBLE ENCODING, not a missing feature. A ustring is UTF-8 on disk
'' by construction, so the I/O path converted to UTF-8 first -- but an ENCODING
'' file's device encodes as well, so the UTF-8 BYTES were re-encoded as if each
'' were a character:
''
''   before:  ustring "héi" into ENCODING "utf16"
''            FF FE 68 00 C3 00 A9 00 69 00     <- "hÃ©i", mojibake
''   after:   FF FE 68 00 E9 00 69 00           <- what WSTRING writes
''
'' Reading was the mirror image: the device decoded UTF-16 to one narrow byte,
'' which was then read as UTF-8, was malformed, and became U+FFFD.
''
'' WSTRING is the reference here: it has always been right, so these compare
'' against it rather than against hand-written expectations.

#macro chkenc( nm, encname )
    scope
        dim as integer ef
        dim as ustring uw = "h" + wchr(&h00E9) + "i" + wchr(&h4E2D)
        dim as wstring * 16 ww = "h" + wchr(&h00E9) + "i" + wchr(&h4E2D)

        '' the WSTRING bytes are the reference
        ef = freefile : open TMPF for output encoding encname as #ef
        print #ef, ww; : close #ef
        ef = freefile : open TMPF for binary access read as #ef
        dim as string want = space(lof(ef))
        get #ef, , want : close #ef

        ef = freefile : open TMPF for output encoding encname as #ef
        print #ef, uw; : close #ef
        ef = freefile : open TMPF for binary access read as #ef
        dim as string got = space(lof(ef))
        get #ef, , got : close #ef

        chk( nm + " bytes match WSTRING", got = want, -1 )
        chk( nm + " wrote something", len(got) > 0, -1 )

        '' and it must round-trip back through LINE INPUT #
        dim as ustring back
        ef = freefile : open TMPF for input encoding encname as #ef
        line input #ef, back : close #ef
        chks( nm + " round-trips", back, uw )
    end scope
#endmacro

chkenc( "utf8",  "utf8"  )
chkenc( "utf16", "utf16" )
chkenc( "utf32", "utf32" )

'' INPUT # must decode too -- it has its own tokeniser, so it is a separate path
scope
    dim as ustring tok = "h" + wchr(&h00E9) + "i"
    dim as integer ef = freefile
    open TMPF for output encoding "utf16" as #ef
    print #ef, tok : close #ef

    dim as ustring got
    ef = freefile : open TMPF for input encoding "utf16" as #ef
    input #ef, got : close #ef
    chks( "INPUT # decodes utf16", got, tok )
end scope

'' The encoded LINE INPUT # grows its own buffer rather than taking a caller
'' maximum, so a plain file and an encoded file have the SAME (absent) line
'' limit. 1000 units crosses the 256-unit initial buffer several times.
scope
    dim as ustring long_line
    for i as integer = 1 to 1000
        long_line += wchr(&h00E9)
    next
    chk( "long line is 1000 units", len(long_line), 1000 )

    dim as integer ef = freefile
    open TMPF for output encoding "utf16" as #ef
    print #ef, long_line : close #ef

    dim as ustring back
    ef = freefile : open TMPF for input encoding "utf16" as #ef
    line input #ef, back : close #ef
    chk ( "long line survives, no truncation", len(back), 1000 )
    chks( "long line round-trips exactly", back, long_line )
end scope

'' A PLAIN file must be untouched by all of this: still UTF-8.
scope
    dim as ustring u = "h" + wchr(&h00E9) + "i"
    dim as integer ef = freefile
    open TMPF for output as #ef
    print #ef, u; : close #ef
    ef = freefile : open TMPF for binary access read as #ef
    dim as string raw = space(lof(ef))
    get #ef, , raw : close #ef
    chk( "plain file is still UTF-8", raw = chr(&h68,&hC3,&hA9,&h69), -1 )
end scope

kill TMPF

print g_run; " checks,"; g_fail; " failed"
if( g_fail <> 0 ) then end 1