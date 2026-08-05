'' Language-level checks for USTRING.
''
'' Standalone rather than fbcunit, so it can run without building the harness:
''   fbc-master/bin/fbc.exe -i fbc-master/inc tests/ustring_lang_test.bas
''
'' Covers phases 1-4: geometry and lifetime, literals, VAR inference and
'' multi-term concat, interop with STRING/ZSTRING/WSTRING, overload resolution,
'' the intrinsic surface, and aggregates. I/O lives in ustring_io_test.bas.
''
'' Where a check compares CONTENT rather than length, that is deliberate: a
'' wrong-width or wrongly-decoded string still reports the right LEN, because
'' the size discriminator carries the length independently of the data.

dim shared as integer g_run, g_fail, g_ptrlen

sub chk( byref nm as string, byval got as longint, byval want as longint )
	g_run += 1
	if( got <> want ) then
		g_fail += 1
		print "FAIL "; nm; " got="; got; " want="; want
	end if
end sub

type URec
    n as integer
    s as ustring
    t as ustring
end type

sub churnUDT()
    for i as integer = 1 to 20000
        dim as URec q
        q.s = "abcdefghij"
        q.t = q.s + q.s
    next
end sub

sub churnUArray()
    for i as integer = 1 to 20000
        dim as ustring a(1 to 4)
        a(1) = "wwww" : a(2) = "xxxx" : a(3) = "yyyy" : a(4) = "zzzz"
    next
end sub

sub churnUDyn()
    for i as integer = 1 to 5000
        redim as ustring d(0 to 9)
        for j as integer = 0 to 9
            d(j) = "0123456789"
        next
        erase d
    next
end sub

sub churnUBoth()
    for i as integer = 1 to 5000
        dim as URec v(1 to 3)
        v(1).s = "aaaa" : v(2).s = "bbbb" : v(3).s = "cccc"
    next
end sub


sub chks( byref nm as string, byref got as ustring, byref want as ustring )
    g_run += 1
    if( got <> want ) then
        g_fail += 1
        dim as string a, b : a = got : b = want
        print "FAIL "; nm; " got=["; a; "] want=["; b; "]"
    end if
end sub


'' -- phase 2b: wstring interop, overloads, copy-back ------------------

sub wmodify( byref u as ustring )
    u = u + "!"
end sub

sub wtakeptr( byval p as wstring ptr )
    g_ptrlen = len(*p)
end sub

function opick overload ( byref s as string ) as integer
    return 1
end function
function opick ( byref w as wstring ) as integer
    return 2
end function
function opick ( byref u as ustring ) as integer
    return 3
end function


function pmk( byref tail as ustring ) as ustring
    dim as ustring r = "x"
    return r + tail
end function

sub pmutate( byval u as ustring )
    u = u + "MUT"
end sub

function ptakeref( byref u as ustring ) as integer
    return len(u)
end function


'' ---------------------------------------------------------------- geometry
'' The descriptor must be the size fbc hardcodes in symb-data.bas, and must
'' match FBUSTRING in src/rtlib/fb_ustring.h -- if these drift, every ustring
'' local is the wrong size on the stack.
dim as ustring u
chk( "sizeof(ustring) = sizeof(string)", sizeof(ustring), sizeof(string) )

'' USTRING * N is N code units, so 2N bytes, on EVERY target. On Windows that
'' coincides with WSTRING * N; on Linux it deliberately does not.
dim as ustring * 16 uf16
dim as ustring * 1  uf1
chk( "sizeof(ustring * 16)", sizeof(uf16), 32 )
chk( "sizeof(ustring * 1)", sizeof(uf1), 2 )

'' ---------------------------------------------------------------- empty ops
dim as ustring a, b, c

chk( "len of fresh ustring", len(a), 0 )

b = a
chk( "len after assign", len(b), 0 )

c = a + b
chk( "len after concat", len(c), 0 )

c = a + b + c
chk( "len after multi-concat", len(c), 0 )

'' self-assignment must not free the buffer and then read it
a = a
chk( "len after self-assign", len(a), 0 )

'' self-concat is what &= lowers to; must not use the operand after growing it
a = a + a
chk( "len after self-concat", len(a), 0 )

'' --------------------------------------------------------------- comparison
if( a = b ) then
	chk( "empty = empty", 1, 1 )
else
	chk( "empty = empty", 0, 1 )
end if

if( a <> b ) then
	chk( "empty <> empty is false", 0, 1 )
else
	chk( "empty <> empty is false", 1, 1 )
end if

'' ------------------------------------------------------- lifetime under load
'' Exercises scope entry/exit: each iteration constructs and destroys three
'' descriptors. A missing fb_UStrDelete shows up here as a steadily growing
'' process, and a double free shows up as a crash.
sub churn( )
	for i as integer = 1 to 10000
		dim as ustring x, y, z
		z = x + y
		z = z + x
	next
end sub
churn( )
chk( "survived 10000 scope enter/exit cycles", 1, 1 )


'' ------------------------------------------------------------- literals
'' Content, not just length: a wrong-width literal still reports the right LEN
'' (the size discriminator carries it), so equality is what actually proves the
'' bytes landed correctly.
dim as ustring l1 = "hello", l2 = "hello", l3 = "world"
chk( "literal len", len(l1), 5 )
chk( "identical literals compare equal", cint(l1 = l2), cint(-1) )
chk( "different literals compare unequal", cint(l1 = l3), cint(0) )

dim as ustring cc = "ab" + "cd"
chk( "literal concat len", len(cc), 4 )
chk( "literal concat content", cint(cc = "abcd"), cint(-1) )

'' u &= x lowers to fb_UStrConcatAssign; must grow in place and keep content
dim as ustring acc
for k as integer = 1 to 100
    acc = acc + "xy"
next
chk( "append loop len", len(acc), 200 )

'' non-BMP: one character, TWO code units. This is the case that separates
'' code-unit counting from character counting.
dim as ustring bmp = "€"
chk( "BMP char (U+20AC) is 1 code unit", len(bmp), 1 )
dim as ustring astral = "𝄞"
chk( "astral char is 2 code units", len(astral), 2 )

print

'' --------------------------------------------------- VAR inference
'' A var-len ustring expression infers a var-len ustring.
dim as ustring va = "ab", vb = "cd"
var vc = va + vb
chk( "VAR from concat: len", len(vc), 4 )
chk( "VAR from concat: content", cint(vc = "abcd"), cint(-1) )
chk( "VAR from concat: is a descriptor", sizeof(vc), sizeof(ustring) )

var vd = va
chk( "VAR from ustring: len", len(vd), 2 )

'' USTRING * N must infer to the DYNAMIC form -- the N has nowhere to live on an
'' expression dtype, and leaving it fixed would give a 1-code-unit variable.
dim as ustring * 8 vf = "abc"
chk( "fixed ustring LEN is content, not capacity", len(vf), 3 )
var vg = vf
chk( "VAR from fixed: promoted to dynamic", sizeof(vg), sizeof(ustring) )
chk( "VAR from fixed: len", len(vg), 3 )
chk( "VAR from fixed: content", cint(vg = "abc"), cint(-1) )

'' ------------------------------------------- multi-term concatenation
'' Lowered to one assign plus N concat-assigns, so no temp descriptor is
'' allocated per term. Correctness of the result is what is checked here;
'' that no fb_UStrConcat is emitted is verified by inspecting the generated C.
dim as ustring m1 = "1", m2 = "22", m3 = "333", m4 = "4444", mres
mres = m1 + m2 + m3 + m4
chk( "4-term concat len", len(mres), 10 )
chk( "4-term concat content", cint(mres = "1223334444"), cint(-1) )

'' the destination appearing on the right must still be correct
mres = m1 + m2
mres = mres + m3 + m4
chk( "self on lhs of multi-concat len", len(mres), 10 )
chk( "self on lhs of multi-concat content", cint(mres = "1223334444"), cint(-1) )

'' a fixed-length destination is excluded from the rewrite; it must still work
dim as ustring * 16 mfix
mfix = m1 + m2 + m3
chk( "fixed dest multi-concat", cint(mfix = "122333"), cint(-1) )

'' ================================================================ PHASE 2
'' Interop: a ustring must work everywhere a string does, and vice versa.
'' Conversion between the two is UTF-8 on every target (D5), so these checks are
'' about fidelity, not just "it compiled".

'' ------------------------------------------------- narrow <-> ustring
dim as string ns = "hello"
dim as ustring nu
nu = ns
chk( "STRING -> USTRING len", len(nu), 5 )
chk( "STRING -> USTRING content", cint(nu = "hello"), cint(-1) )

dim as string back
back = nu
chk( "USTRING -> STRING len", len(back), 5 )
chk( "USTRING -> STRING content", cint(back = "hello"), cint(-1) )

dim as zstring * 16 nz = "hey"
dim as ustring uz
uz = nz
chk( "ZSTRING -> USTRING", len(uz), 3 )

'' mixed concatenation, both orders; the narrow side is decoded, never
'' reinterpreted as UTF-16
dim as ustring mixres
mixres = nu + ns
chk( "ustring + string len", len(mixres), 10 )
chk( "ustring + string content", cint(mixres = "hellohello"), cint(-1) )
mixres = ns + nu
chk( "string + ustring len", len(mixres), 10 )

'' comparison across the two worlds
chk( "ustring = string", cint(nu = ns), cint(-1) )
chk( "ustring <> other string", cint(nu = "nope"), cint(0) )

'' ---------------------------------------------- UTF-8 round-trip fidelity
'' The multi-byte cases are the ones that would silently corrupt if the
'' conversion treated bytes as code units.
dim as string e1 = "é", e2 = "€", e3 = "𝄞"
dim as ustring q1, q2, q3
q1 = e1 : q2 = e2 : q3 = e3
chk( "U+00E9: 2 bytes -> 1 unit", len(q1), 1 )
chk( "U+20AC: 3 bytes -> 1 unit", len(q2), 1 )
chk( "U+1D11E: 4 bytes -> 2 units", len(q3), 2 )

dim as string r1, r2, r3
r1 = q1 : r2 = q2 : r3 = q3
chk( "U+00E9 round-trips", cint(r1 = e1), cint(-1) )
chk( "U+20AC round-trips", cint(r2 = e2), cint(-1) )
chk( "U+1D11E round-trips", cint(r3 = e3), cint(-1) )

'' malformed UTF-8 becomes U+FFFD rather than failing -- a damaged file must
'' still open
dim as string badbytes = chr(255) + "ok"
dim as ustring ubad
ubad = badbytes
chk( "malformed byte -> U+FFFD, text preserved", len(ubad), 3 )

'' --------------------------------------- procedures: params and results
dim as ustring pt = "yz"
chk( "function result len", len(pmk(pt)), 3 )
chk( "function result content", cint(pmk(pt) = "xyz"), cint(-1) )
chk( "result inside a concat", len(pmk(pt) + pmk(pt)), 6 )
chk( "result fed to a param", len(pmk(pmk(pt))), 4 )

'' BYVAL must copy. A ustring is non-trivial so it always travels by address;
'' without the temp copy the callee would be editing the caller's variable.
dim as ustring porig = "abc"
pmutate( porig )
chk( "byval did not mutate caller", len(porig), 3 )

'' A DISCARDED result still occupies a pooled temp descriptor. There are only
'' 256, so a loop that ignores results exhausts the pool and every later call
'' quietly returns the null descriptor -- which reads as length 0, not a crash.
for pi as integer = 1 to 20000
    pmk( pt )
next
chk( "20000 discarded results, pool not exhausted", len(pmk(pt)), 3 )

'' a narrow argument passed to a ustring parameter converts through UTF-8
dim as string pns = "hi"
chk( "narrow arg -> ustring param", ptakeref( pns ), 2 )

'' ------------------------------------------------- wstring <-> ustring
'' A wstring is UTF-16 where wchar_t is 16 bits and UTF-32 where it is 32.
'' Both directions must preserve text either way.
dim as wstring * 32 xw = wstr("hello")
dim as ustring xu
xu = xw
chk( "WSTRING -> USTRING len", len(xu), 5 )
chk( "WSTRING -> USTRING content", cint(xu = "hello"), cint(-1) )

dim as wstring * 32 xw2
xw2 = xu
chk( "USTRING -> WSTRING len", len(xw2), 5 )

dim as ustring xm
xm = xu + xw
chk( "ustring + wstring", len(xm), 10 )
xm = xw + xu
chk( "wstring + ustring", len(xm), 10 )
chk( "ustring = wstring", cint(xu = xw), cint(-1) )

'' An astral character is 2 ustring units. Round-tripping it through a
'' wstring must not lose the pairing.
dim as ustring xa = "𝄞"
dim as wstring * 8 xwa
xwa = xa
dim as ustring xback
xback = xwa
chk( "astral survives ustring->wstring->ustring", len(xback), 2 )
chk( "astral content preserved", cint(xback = xa), cint(-1) )

'' ------------------------------------------------ overload resolution
'' All three string types share FB_DATACLASS_STRING, so without explicit
'' ranking every one of these calls is ambiguous.
dim as string  os = "a"
dim as wstring * 8 ow = wstr("a")
dim as ustring ou = "a"
chk( "string arg picks string ovl", opick(os), 1 )
chk( "wstring arg picks wstring ovl", opick(ow), 2 )
chk( "ustring arg picks ustring ovl", opick(ou), 3 )
chk( "literal picks string ovl", opick("a"), 1 )

'' ---------------------------------------------------------- copy-back
'' BYREF through a converting parameter must write the result back, or
'' BYREF is a lie for every non-ustring argument.
dim as string cs = "abc"
wmodify( cs )
chk( "narrow arg copied back", len(cs), 4 )
chk( "narrow copy-back content", cint(cs = "abc!"), cint(-1) )

dim as wstring * 16 cw = wstr("xy")
wmodify( cw )
chk( "wstring arg copied back", len(cw), 3 )

dim as ustring cu = "q"
wmodify( cu )
chk( "native ustring modified byref", len(cu), 2 )

'' ------------------------------------------- ustring -> WSTRING PTR
'' Where wchar_t is 16 bits this hands out the buffer with no conversion;
'' where it is wider the compiler warns and re-encodes.
wtakeptr( ou )
chk( "ustring passed as wstring ptr", g_ptrlen, 1 )

'' ================================================================ PHASE 3
'' Intrinsics. Positions and lengths are CODE UNITS and 1-based, matching
'' LEN() and [] indexing.

dim as ustring i3 = "Hello World"
chks( "LEFT", left(i3, 5), "Hello" )
chks( "RIGHT", right(i3, 5), "World" )
chks( "MID 2-arg", mid(i3, 7), "World" )
chks( "MID 3-arg", mid(i3, 1, 5), "Hello" )
chk ( "INSTR", instr(i3, "World"), 7 )
chk ( "INSTR not found is 0", instr(i3, "zzz"), 0 )
chk ( "INSTR with start", instr(4, i3, "l"), 4 )
chk ( "INSTRREV", instrrev(i3, "l"), 10 )
chks( "UCASE", ucase(i3), "HELLO WORLD" )
chks( "LCASE", lcase(i3), "hello world" )

dim as ustring i3pad = "  xy  "
chks( "TRIM", trim(i3pad), "xy" )
chks( "LTRIM", ltrim(i3pad), "xy  " )
chks( "RTRIM", rtrim(i3pad), "  xy" )
chks( "TRIM ANY", trim("--ab--", any "-"), "ab" )
chk ( "SPACE", len(space(4)), 4 )
chks( "STRING n,code", string(3, asc("z")), "zzz" )

'' ---------------------------------------------- Unicode case mapping
'' From the generated BMP table, NOT towupper/towlower -- those are
'' locale-dependent and would fold differently per platform and per libc.
dim as ustring xl1 = "éèç"
dim as ustring xu1 = "ÉÈÇ"
chks( "UCASE latin-1 accents", ucase(xl1), xu1 )
chks( "LCASE latin-1 accents", lcase(xu1), xl1 )

dim as ustring xl2 = "αβγ"
dim as ustring xu2 = "ΑΒΓ"
chks( "UCASE greek", ucase(xl2), xu2 )
chks( "LCASE greek", lcase(xu2), xl2 )

dim as ustring xl3 = "абв"
dim as ustring xu3 = "АБВ"
chks( "UCASE cyrillic", ucase(xl3), xu3 )

'' An astral character has no simple case mapping. It must pass through
'' untouched rather than having its surrogate halves mapped independently,
'' which would corrupt the character.
dim as ustring xast = "𝄞"
chks( "UCASE leaves astral alone", ucase(xast), xast )
chk ( "astral still 2 units after UCASE", len(ucase(xast)), 2 )

dim as ustring xcjk = "中文"
chks( "UCASE leaves CJK alone", ucase(xcjk), xcjk )

'' slicing is unit-based, so an astral character occupies two positions
dim as ustring xmix = "a𝄞z"
chk ( "mixed len is 4 units", len(xmix), 4 )
chks( "LEFT 1 of mixed", left(xmix,1), "a" )
chks( "RIGHT 1 of mixed", right(xmix,1), "z" )
chk ( "INSTR finds z at unit 4", instr(xmix, "z"), 4 )

'' ----------------------------------------- ASC, indexing, LSET/RSET, SWAP
'' ASC and [] both yield a CODE UNIT, consistent with LEN(). A position
'' holding a surrogate half yields that half -- decoding a whole scalar is
'' the job of the codepoint helpers, not of ASC.
dim as ustring ia = "hello"
chk( "ASC default position", asc(ia), 104 )
chk( "ASC at position 2", asc(ia, 2), 101 )
chk( "ASC out of range is 0", asc(ia, 99), 0 )
chk( "index [0]", ia[0], 104 )
chk( "index [4]", ia[4], 111 )

'' a non-ASCII BMP character is ONE unit with its real codepoint value,
'' which is what separates this from a byte-oriented string
dim as ustring ib = "é€"
chk( "index U+00E9", ib[0], 233 )
chk( "index U+20AC", ib[1], 8364 )
chk( "ASC of U+20AC", asc(ib,2), 8364 )

'' LSET/RSET pad with spaces and never resize the destination
dim as ustring iL = "xxxxxx"
lset iL, "ab"
chks( "LSET pads right", iL, "ab    " )
dim as ustring iR = "xxxxxx"
rset iR, "ab"
chks( "RSET pads left", iR, "    ab" )

'' SWAP exchanges the two descriptors -- O(1), no text moved
dim as ustring iS1 = "one", iS2 = "two"
swap iS1, iS2
chks( "SWAP first", iS1, "two" )
chks( "SWAP second", iS2, "one" )

'' -------------------------------------------- numeric conversions
'' These need no ustring-specific runtime: their text is ASCII, so the
'' UTF-8 conversion is lossless in both directions.
dim as ustring iv = "3.5"
chk( "VAL", cint(val(iv)*10), 35 )
dim as ustring ii = "42"
chk( "VALINT", valint(ii), 42 )
dim as ustring ih : ih = hex(255)
chks( "HEX -> ustring", ih, "FF" )
dim as ustring ist : ist = str(42)
chks( "STR -> ustring", ist, "42" )

'' WCHR is how a ustring is built from a codepoint: it produces a wstring,
'' which converts losslessly. CHR would produce a single BYTE, which is not
'' valid UTF-8 above 127.
dim as ustring iw : iw = wchr(233)
chks( "WCHR builds a codepoint", iw, "é" )
chk ( "STRPTR is non-null", cint(strptr(ia) <> 0), -1 )

'' ================================================================ PHASE 4
'' Aggregates. A ustring field or array element owns a heap buffer, so the
'' implicit ctor/copy/dtor and the array destructors all have to fire.

dim as URec ar1
ar1.s = "hello" : ar1.t = "wide"
chk ( "UDT field len", len(ar1.s), 5 )
chks( "UDT field content", ar1.s, "hello" )
chk ( "UDT second field", len(ar1.t), 4 )

'' whole-UDT copy must deep-copy the field, not alias the buffer
dim as URec ar2
ar2 = ar1
ar2.s = ar2.s + "!"
chk( "UDT copy is independent", len(ar1.s), 5 )
chk( "UDT copy was modified", len(ar2.s), 6 )

dim as ustring aarr(1 to 3)
aarr(1) = "one" : aarr(2) = "two" : aarr(3) = "three"
chk ( "array element", len(aarr(1)), 3 )
chks( "array element content", aarr(3), "three" )

redim as ustring adyn(0 to 2)
adyn(0) = "aa" : adyn(1) = "bb" : adyn(2) = "cc"
chk( "dynamic array element", len(adyn(1)), 2 )
erase adyn
redim adyn(0 to 1)
adyn(0) = "z"
chk( "after erase and redim", len(adyn(0)), 1 )

'' Leak stress. A missing destructor shows up here as descriptor-pool
'' exhaustion (later calls silently return length 0) or as unbounded growth.
churnUDT()
chk( "20000 UDT scopes", 1, 1 )
churnUArray()
chk( "20000 array scopes", 1, 1 )
churnUDyn()
chk( "5000 dynamic redim/erase cycles", 1, 1 )
churnUBoth()
chk( "5000 UDT-array scopes", 1, 1 )

'' the pool must still be usable afterwards -- this is what catches a leak
dim as URec apost
apost.s = "still works"
chk( "descriptor pool not exhausted", len(apost.s), 11 )

print g_run; " checks,"; g_fail; " failed"
if( g_fail <> 0 ) then
	end 1
end if
