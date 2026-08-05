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

dim shared as integer g_run, g_fail

sub chk( byref nm as string, byval got as longint, byval want as longint )
	g_run += 1
	if( got <> want ) then
		g_fail += 1
		print "FAIL "; nm; " got="; got; " want="; want
	end if
end sub

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

print g_run; " checks,"; g_fail; " failed"

if( g_fail <> 0 ) then
	end 1
end if
