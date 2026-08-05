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

print
print g_run; " checks,"; g_fail; " failed"

if( g_fail <> 0 ) then
	end 1
end if
