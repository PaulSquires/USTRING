/* Phase 0 verification: standalone tests for the ustring codecs.
**
** These live OUTSIDE fbc-master on purpose. fbc's own suite is fbcunit .bas
** tests, so a C-level harness has no home in the tree and would only make the
** upstream patch noisier. It is kept here because the codec is the one piece of
** ustring that can be proved correct before any compiler work exists.
**
** Build (from C:\dev\ustring):
**   gcc -O2 -Wall -I fbc-master/src/rtlib tests/ustr_codec_test.c \
**       fbc-master/src/rtlib/ustr_utf.c fbc-master/src/rtlib/ustr_prim.c \
**       -o tests/ustr_codec_test.exe
*/

#include "fb.h"
#include <stdio.h>

static int g_fail = 0;
static int g_run  = 0;

static void hexdump_u( const FB_UCHAR *u, ssize_t n )
{
	ssize_t i;
	printf( "[" );
	for( i = 0; i < n; i++ )
		printf( "%s%04X", i ? " " : "", u[i] );
	printf( "]" );
}

static void hexdump_b( const char *b, ssize_t n )
{
	ssize_t i;
	printf( "[" );
	for( i = 0; i < n; i++ )
		printf( "%s%02X", i ? " " : "", (unsigned char)b[i] );
	printf( "]" );
}

/* Decode src_bytes of UTF-8 and compare against an expected UTF-16 unit list. */
static void chk_decode( const char *name,
                        const char *src, ssize_t src_bytes,
                        const FB_UCHAR *want, ssize_t want_units )
{
	FB_UCHAR got[64];
	ssize_t n, measured;
	int ok;

	g_run++;

	/* measure-only pass must agree with the writing pass */
	measured = fb_hUtf8ToUtf16( src, src_bytes, NULL, 0 );
	n = fb_hUtf8ToUtf16( src, src_bytes, got, 63 );

	ok = (n == want_units) && (measured == n);
	if( ok )
	{
		ssize_t i;
		for( i = 0; i < n; i++ )
			if( got[i] != want[i] ) { ok = 0; break; }
	}
	/* the NUL terminator must be present */
	if( ok && got[n] != 0 )
		ok = 0;
	/* the documented upper bound must hold */
	if( ok && (n > FB_UTF8_TO_UTF16_MAX( src_bytes )) )
		ok = 0;

	if( !ok )
	{
		g_fail++;
		printf( "FAIL decode %-28s src=", name );
		hexdump_b( src, src_bytes );
		printf( "\n     got=" ); hexdump_u( got, n );
		printf( " (n=%d, measured=%d)\n", (int)n, (int)measured );
		printf( "    want=" ); hexdump_u( want, want_units );
		printf( " (n=%d)\n", (int)want_units );
	}
}

/* Encode UTF-16 units and compare against expected UTF-8 bytes. */
static void chk_encode( const char *name,
                        const FB_UCHAR *src, ssize_t src_units,
                        const char *want, ssize_t want_bytes )
{
	char got[128];
	ssize_t n, measured;
	int ok;

	g_run++;

	measured = fb_hUtf16ToUtf8( src, src_units, NULL, 0 );
	n = fb_hUtf16ToUtf8( src, src_units, got, 127 );

	ok = (n == want_bytes) && (measured == n);
	if( ok )
	{
		ssize_t i;
		for( i = 0; i < n; i++ )
			if( got[i] != want[i] ) { ok = 0; break; }
	}
	if( ok && got[n] != 0 )
		ok = 0;
	if( ok && (n > FB_UTF16_TO_UTF8_MAX( src_units )) )
		ok = 0;

	if( !ok )
	{
		g_fail++;
		printf( "FAIL encode %-28s src=", name );
		hexdump_u( src, src_units );
		printf( "\n     got=" ); hexdump_b( got, n );
		printf( " (n=%d, measured=%d)\n", (int)n, (int)measured );
		printf( "    want=" ); hexdump_b( want, want_bytes );
		printf( " (n=%d)\n", (int)want_bytes );
	}
}

/* UTF-8 -> UTF-16 -> UTF-8 must be the identity for well-formed input. */
static void chk_roundtrip( const char *name, const char *src, ssize_t src_bytes )
{
	FB_UCHAR mid[128];
	char back[256];
	ssize_t nmid, nback;
	int ok;

	g_run++;

	nmid  = fb_hUtf8ToUtf16( src, src_bytes, mid, 127 );
	nback = fb_hUtf16ToUtf8( mid, nmid, back, 255 );

	ok = (nback == src_bytes);
	if( ok )
	{
		ssize_t i;
		for( i = 0; i < nback; i++ )
			if( back[i] != src[i] ) { ok = 0; break; }
	}

	if( !ok )
	{
		g_fail++;
		printf( "FAIL rtrip  %-28s src=", name );
		hexdump_b( src, src_bytes );
		printf( "\n    back=" ); hexdump_b( back, nback );
		printf( "\n" );
	}
}

static void chk_int( const char *name, long long got, long long want )
{
	g_run++;
	if( got != want )
	{
		g_fail++;
		printf( "FAIL %-34s got=%lld want=%lld\n", name, got, want );
	}
}

#define U(...) ((const FB_UCHAR[]){ __VA_ARGS__ })
#define B(...) ((const char[]){ __VA_ARGS__ })

int main( void )
{
	/* ---------------------------------------------------------- well-formed */
	chk_decode( "empty",        "", 0, U(0), 0 );
	chk_decode( "ascii",        "Hi!", 3, U(0x48,0x69,0x21), 3 );
	chk_decode( "2-byte e-acute", B((char)0xC3,(char)0xA9), 2, U(0x00E9), 1 );
	chk_decode( "3-byte euro",  B((char)0xE2,(char)0x82,(char)0xAC), 3, U(0x20AC), 1 );
	chk_decode( "3-byte CJK",   B((char)0xE4,(char)0xB8,(char)0xAD), 3, U(0x4E2D), 1 );
	/* U+1D11E MUSICAL SYMBOL G CLEF -> surrogate pair */
	chk_decode( "4-byte astral", B((char)0xF0,(char)0x9D,(char)0x84,(char)0x9E), 4,
	            U(0xD834,0xDD1E), 2 );
	/* U+10FFFF, the largest scalar value */
	chk_decode( "4-byte max cp", B((char)0xF4,(char)0x8F,(char)0xBF,(char)0xBF), 4,
	            U(0xDBFF,0xDFFF), 2 );
	/* U+0800 and U+FFFF, the 3-byte boundaries */
	chk_decode( "3-byte low bound", B((char)0xE0,(char)0xA0,(char)0x80), 3, U(0x0800), 1 );
	chk_decode( "3-byte high bound", B((char)0xEF,(char)0xBF,(char)0xBF), 3, U(0xFFFF), 1 );

	/* embedded NUL must survive -- length is authoritative, not the terminator */
	chk_decode( "embedded NUL", B('A','B',0,'C','D'), 5,
	            U(0x41,0x42,0x0000,0x43,0x44), 5 );

	/* ------------------------------------------------------------ malformed */
	/* C0/C1 are never valid leads: each is its own maximal subpart, then the
	   stray continuation is another. Two U+FFFD, per Unicode recommendation. */
	chk_decode( "overlong C0 80", B((char)0xC0,(char)0x80), 2, U(0xFFFD,0xFFFD), 2 );
	/* E0 80 80: E0 requires a second byte A0..BF, so all three are bad */
	chk_decode( "overlong E0 80 80", B((char)0xE0,(char)0x80,(char)0x80), 3,
	            U(0xFFFD,0xFFFD,0xFFFD), 3 );
	/* ED A0 80 would encode U+D800, a surrogate -- not a scalar value */
	chk_decode( "surrogate ED A0 80", B((char)0xED,(char)0xA0,(char)0x80), 3,
	            U(0xFFFD,0xFFFD,0xFFFD), 3 );
	/* F0 80 .. would be overlong */
	chk_decode( "overlong F0 80", B((char)0xF0,(char)0x80,(char)0x80,(char)0x80), 4,
	            U(0xFFFD,0xFFFD,0xFFFD,0xFFFD), 4 );
	/* F4 90 .. would exceed U+10FFFF */
	chk_decode( "beyond max F4 90", B((char)0xF4,(char)0x90,(char)0x80,(char)0x80), 4,
	            U(0xFFFD,0xFFFD,0xFFFD,0xFFFD), 4 );
	/* truncated sequences consume their maximal subpart: ONE U+FFFD each */
	chk_decode( "truncated 3-byte", B((char)0xE2,(char)0x82), 2, U(0xFFFD), 1 );
	chk_decode( "truncated 4-byte", B((char)0xF0,(char)0x9D,(char)0x84), 3, U(0xFFFD), 1 );
	/* stray continuation, and leads that can never start a sequence */
	chk_decode( "stray cont 80", B((char)0x80), 1, U(0xFFFD), 1 );
	chk_decode( "invalid F5", B((char)0xF5), 1, U(0xFFFD), 1 );
	chk_decode( "invalid FF", B((char)0xFF), 1, U(0xFFFD), 1 );
	/* recovery: a bad byte must not swallow the good text after it */
	chk_decode( "resync after bad", B((char)0xFF,'o','k'), 3, U(0xFFFD,0x6F,0x6B), 3 );

	/* -------------------------------------------------------------- encoding */
	chk_encode( "enc ascii", U(0x48,0x69), 2, "Hi", 2 );
	chk_encode( "enc 2-byte", U(0x00E9), 1, B((char)0xC3,(char)0xA9), 2 );
	chk_encode( "enc 3-byte", U(0x20AC), 1, B((char)0xE2,(char)0x82,(char)0xAC), 3 );
	chk_encode( "enc astral pair", U(0xD834,0xDD1E), 2,
	            B((char)0xF0,(char)0x9D,(char)0x84,(char)0x9E), 4 );
	/* lone surrogates are not scalar values -> U+FFFD (EF BF BD) */
	chk_encode( "enc lone high sur", U(0xD834), 1, B((char)0xEF,(char)0xBF,(char)0xBD), 3 );
	chk_encode( "enc lone low sur", U(0xDD1E), 1, B((char)0xEF,(char)0xBF,(char)0xBD), 3 );
	chk_encode( "enc high then ascii", U(0xD834,0x41), 2,
	            B((char)0xEF,(char)0xBF,(char)0xBD,'A'), 4 );
	chk_encode( "enc embedded NUL", U(0x41,0x0000,0x42), 3, B('A',0,'B'), 3 );

	/* ------------------------------------------------------------ round-trip */
	chk_roundtrip( "rt ascii", "Hello, world!", 13 );
	chk_roundtrip( "rt 2-byte", B((char)0xC3,(char)0xA9,(char)0xC3,(char)0xA8), 4 );
	chk_roundtrip( "rt 3-byte", B((char)0xE4,(char)0xB8,(char)0xAD,(char)0xE6,(char)0x96,(char)0x87), 6 );
	chk_roundtrip( "rt astral", B((char)0xF0,(char)0x9D,(char)0x84,(char)0x9E), 4 );
	chk_roundtrip( "rt mixed", B('a',(char)0xC3,(char)0xA9,(char)0xE4,(char)0xB8,(char)0xAD,
	                             (char)0xF0,(char)0x9D,(char)0x84,(char)0x9E,'z'), 11 );
	chk_roundtrip( "rt embedded NUL", B('A',0,'B'), 3 );

	/* ------------------------------------------------------------ UTF-32 leg */
	{
		static const uint32_t w32[] = { 0x41, 0x4E2D, 0x1D11E, 0xD800, 0x110000 };
		FB_UCHAR got[16];
		ssize_t n = fb_hUtf32ToUtf16( w32, 5, got, 15 );
		chk_int( "utf32->16 count", n, 6 );   /* 1+1+2+1+1 */
		chk_int( "utf32->16 [0]", got[0], 0x41 );
		chk_int( "utf32->16 [1]", got[1], 0x4E2D );
		chk_int( "utf32->16 [2]", got[2], 0xD834 );
		chk_int( "utf32->16 [3]", got[3], 0xDD1E );
		chk_int( "utf32->16 lone sur -> FFFD", got[4], 0xFFFD );
		chk_int( "utf32->16 out of range -> FFFD", got[5], 0xFFFD );
	}
	{
		static const FB_UCHAR w16[] = { 0x41, 0xD834, 0xDD1E, 0xD834 };
		uint32_t got[16];
		ssize_t n = fb_hUtf16ToUtf32( w16, 4, got, 15 );
		chk_int( "utf16->32 count", n, 3 );
		chk_int( "utf16->32 [0]", got[0], 0x41 );
		chk_int( "utf16->32 [1] astral", got[1], 0x1D11E );
		chk_int( "utf16->32 [2] lone sur -> FFFD", got[2], 0xFFFD );
	}

	/* ------------------------------------------------- codepoint iteration */
	{
		static const FB_UCHAR s[] = { 0x41, 0xD834, 0xDD1E, 0xDD1E, 0x42 };
		ssize_t used = 0;
		chk_int( "cp@0", fb_hUStrCodepointAt( s, 5, 0, &used ), 0x41 );
		chk_int( "cp@0 used", used, 1 );
		chk_int( "cp@1 pair", fb_hUStrCodepointAt( s, 5, 1, &used ), 0x1D11E );
		chk_int( "cp@1 used", used, 2 );
		chk_int( "cp@3 lone low", fb_hUStrCodepointAt( s, 5, 3, &used ), 0xFFFD );
		chk_int( "cp@3 used", used, 1 );
		/* a lone high surrogate at the very end must still advance by 1, or a
		   caller looping on units_used would spin forever */
		chk_int( "cp@1 of truncated pair", fb_hUStrCodepointAt( s, 2, 1, &used ), 0xFFFD );
		chk_int( "cp truncated used", used, 1 );
	}

	/* ---------------------------------------------------------- primitives */
	{
		static const FB_UCHAR a[] = { 'a','b','c', 0 };
		static const FB_UCHAR b[] = { 'a','b','d', 0 };
		static const FB_UCHAR e[] = { 0 };
		FB_UCHAR buf[8];

		chk_int( "ustrlen abc", fb_hUStrLen( a ), 3 );
		chk_int( "ustrlen empty", fb_hUStrLen( e ), 0 );
		chk_int( "ustrlen NULL", fb_hUStrLen( NULL ), 0 );
		chk_int( "cmp abc<abd", fb_hUStrCompare( a, 3, b, 3 ), -1 );
		chk_int( "cmp abd>abc", fb_hUStrCompare( b, 3, a, 3 ), 1 );
		chk_int( "cmp equal", fb_hUStrCompare( a, 3, a, 3 ), 0 );
		chk_int( "cmp prefix shorter", fb_hUStrCompare( a, 2, a, 3 ), -1 );
		chk_int( "chr found", fb_hUStrChr( a, 3, 'b' ), 1 );
		chk_int( "chr absent", fb_hUStrChr( a, 3, 'z' ), -1 );
		chk_int( "str found", fb_hUStrStr( a, 3, b, 2 ), 0 );
		chk_int( "str absent", fb_hUStrStr( a, 3, b, 3 ), -1 );
		chk_int( "str empty needle", fb_hUStrStr( a, 3, e, 0 ), 0 );

		/* a fill value whose two bytes differ must not take the memset path */
		fb_hUStrFill( buf, 0x1234, 4 );
		chk_int( "fill[0]", buf[0], 0x1234 );
		chk_int( "fill[3]", buf[3], 0x1234 );
		fb_hUStrFill( buf, 0x2020, 3 );
		chk_int( "fill memset path", buf[2], 0x2020 );

		fb_hUStrCopy( buf, a, 3 );
		chk_int( "copy terminates", buf[3], 0 );
	}

	printf( "\n%d checks, %d failed\n", g_run, g_fail );
	return g_fail != 0;
}
