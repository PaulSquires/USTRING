'' Language-level checks for USTRING.
''
'' Standalone rather than fbcunit, so it can run without building the harness:
''   fbc-master/bin/fbc.exe -i fbc-master/inc tests/ustring_lang_test.bas
''
'' NOTE the ceiling on what can be tested here: a ustring cannot be given
'' content yet, because literals are unimplemented and mixing a ustring with a
'' narrow string is deliberately rejected rather than silently corrupted.
'' See NOTES.md. Everything below is therefore about geometry, lifetime and the
'' empty-string edges -- which is exactly where a descriptor type goes wrong.

dim shared as integer g_run, g_fail, g_ptrlen

sub chk( byref nm as string, byval got as longint, byval want as longint )
	g_run += 1
	if( got <> want ) then
		g_fail += 1
		print "FAIL "; nm; " got="; got; " want="; want
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

print g_run; " checks,"; g_fail; " failed"
if( g_fail <> 0 ) then
	end 1
end if
