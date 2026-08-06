/* The wstring <-> ustring conversion at ALL THREE wchar widths.
**
** WHY THIS TEST EXISTS
**
** hWcharToUnits/hUnitsToWchar branch on sizeof(FB_WCHAR), and those branches
** fold away at compile time. On Windows FB_WCHAR is 16 bits, so the UTF-32
** branch (Linux) and the 8-bit branch (DOS) are never compiled into anything
** runnable -- they are dead code on the only target that can be built here.
**
** Dead code is untested code, and it is precisely the code a Windows developer
** cannot check. Every claim about ustring on Linux runs through the UTF-32
** branch, and until now nothing had ever executed it.
**
** This includes fbc-master/src/rtlib/ustr_wchar_conv.h three times, once per
** width, so all three branches run natively. It tests THAT source, not a copy.
**
** Build (from C:\dev\ustring):
**   gcc -O2 -Wall -I fbc-master/src/rtlib tests/ustr_wchar_test.c \
**       fbc-master/src/rtlib/ustr_utf.c fbc-master/src/rtlib/ustr_prim.c \
**       -o tests/ustr_wchar_test.exe
*/

#include "fb.h"
#include <stdio.h>

/* --- the three instantiations ------------------------------------------- */

#define UWCONV_WCHAR   uint16_t
#define UWCONV_TOUNITS w16_to_units
#define UWCONV_TOWCHAR units_to_w16
#include "ustr_wchar_conv.h"

#define UWCONV_WCHAR   uint32_t
#define UWCONV_TOUNITS w32_to_units
#define UWCONV_TOWCHAR units_to_w32
#include "ustr_wchar_conv.h"

#define UWCONV_WCHAR   char
#define UWCONV_TOUNITS w8_to_units
#define UWCONV_TOWCHAR units_to_w8
#include "ustr_wchar_conv.h"

/* --- harness ------------------------------------------------------------- */

static int g_run = 0, g_fail = 0;

static void chk_units( const char *name, const FB_UCHAR *got, ssize_t got_n,
                       const FB_UCHAR *want, ssize_t want_n )
{
	ssize_t i;
	int ok = (got_n == want_n);

	g_run++;
	if( ok )
		for( i = 0; i < want_n; i++ )
			if( got[i] != want[i] ) { ok = 0; break; }

	if( !ok )
	{
		g_fail++;
		printf( "FAIL %s\n  got  [", name );
		for( i = 0; i < got_n; i++ ) printf( "%s%04X", i ? " " : "", got[i] );
		printf( "]\n  want [" );
		for( i = 0; i < want_n; i++ ) printf( "%s%04X", i ? " " : "", want[i] );
		printf( "]\n" );
	}
}

static void chk_n( const char *name, ssize_t got, ssize_t want )
{
	g_run++;
	if( got != want )
	{
		g_fail++;
		printf( "FAIL %s: got %ld want %ld\n", name, (long)got, (long)want );
	}
}

#define CHK_W32( name, arr, want_units )                                      \
	do {                                                                      \
		FB_UCHAR buf[64];                                                     \
		ssize_t src_n = (ssize_t)(sizeof(arr)/sizeof((arr)[0]));              \
		ssize_t measured = w32_to_units( (arr), src_n, NULL, 0 );             \
		ssize_t n = w32_to_units( (arr), src_n, buf, measured );              \
		chk_n( name " measure == write", measured, n );                       \
		chk_units( name, buf, n, (want_units),                                \
		           (ssize_t)(sizeof(want_units)/sizeof((want_units)[0])) );   \
	} while( 0 )

int main( void )
{
	/* ================================================== 16-bit (Windows) ==
	   The identity case, included so the three widths are compared against
	   each other rather than each being read in isolation. */
	{
		static const uint16_t src[] = { 'h', 0x00E9, 0xD834, 0xDD1E, 'i' };
		static const FB_UCHAR want[] = { 'h', 0x00E9, 0xD834, 0xDD1E, 'i' };
		FB_UCHAR buf[64];
		ssize_t n = w16_to_units( src, 5, buf, 64 );

		chk_units( "w16 -> units is identity, surrogates intact", buf, n, want, 5 );
		chk_n( "w16 measure", w16_to_units( src, 5, NULL, 0 ), 5 );
	}
	{
		static const FB_UCHAR src[] = { 'h', 0x00E9, 0xD834, 0xDD1E, 'i' };
		uint16_t buf[64];
		ssize_t n = units_to_w16( src, 5, buf, 64 );
		int ok = (n == 5) && buf[1] == 0x00E9 && buf[2] == 0xD834 && buf[3] == 0xDD1E;

		g_run++;
		if( !ok ) { g_fail++; printf( "FAIL units -> w16 identity\n" ); }
	}

	/* ==================================================== 32-bit (Linux) ==
	   THE BRANCH THAT HAS NEVER RUN ANYWHERE. */
	{
		/* ASCII and BMP pass through as one unit each */
		static const uint32_t src[] = { 'h', 0x00E9, 0x20AC, 'i' };
		static const FB_UCHAR want[] = { 'h', 0x00E9, 0x20AC, 'i' };
		CHK_W32( "w32 BMP -> units", src, want );
	}
	{
		/* an astral scalar becomes a SURROGATE PAIR, so the unit count is not
		   the character count -- the whole reason the measure pass exists */
		static const uint32_t src[] = { 'a', 0x1D11E, 'b' };
		static const FB_UCHAR want[] = { 'a', 0xD834, 0xDD1E, 'b' };
		CHK_W32( "w32 astral -> surrogate pair", src, want );
	}
	{
		/* a scalar above U+10FFFF is not representable */
		static const uint32_t src[] = { 0x110000u, 'x' };
		static const FB_UCHAR want[] = { 0xFFFD, 'x' };
		CHK_W32( "w32 out-of-range -> U+FFFD", src, want );
	}
	{
		/* a lone surrogate is not a valid scalar value in UTF-32 either */
		static const uint32_t src[] = { 0xD834u, 'x' };
		static const FB_UCHAR want[] = { 0xFFFD, 'x' };
		CHK_W32( "w32 surrogate scalar -> U+FFFD", src, want );
	}
	{
		/* the measure pass must count 2 for an astral scalar; getting this
		   wrong would under-allocate and truncate on Linux only */
		static const uint32_t src[] = { 0x1D11E, 0x10FFFF, 'z' };
		chk_n( "w32 measure counts surrogate pairs",
		       w32_to_units( src, 3, NULL, 0 ), 5 );
	}
	{
		/* UTF-16 -> UTF-32: a pair collapses back to one char */
		static const FB_UCHAR src[] = { 'a', 0xD834, 0xDD1E, 'b' };
		uint32_t buf[64];
		ssize_t n = units_to_w32( src, 4, buf, 64 );

		chk_n( "units -> w32 collapses the pair", n, 3 );
		g_run++;
		if( !(buf[0] == 'a' && buf[1] == 0x1D11E && buf[2] == 'b') )
		{
			g_fail++;
			printf( "FAIL units -> w32 values: %08lX %08lX %08lX\n",
			        (unsigned long)buf[0], (unsigned long)buf[1],
			        (unsigned long)buf[2] );
		}
		chk_n( "units -> w32 measure", units_to_w32( src, 4, NULL, 0 ), 3 );
	}
	{
		/* a LONE surrogate in the ustring must not consume its neighbour */
		static const FB_UCHAR src[] = { 0xD834, 'x' };
		uint32_t buf[64];
		ssize_t n = units_to_w32( src, 2, buf, 64 );

		chk_n( "units -> w32 lone surrogate stays 2 chars", n, 2 );
		g_run++;
		if( !(buf[0] == 0xFFFD && buf[1] == 'x') )
		{
			g_fail++;
			printf( "FAIL lone surrogate -> w32: %08lX %08lX\n",
			        (unsigned long)buf[0], (unsigned long)buf[1] );
		}
	}
	{
		/* ROUND TRIP through the Linux representation */
		static const FB_UCHAR orig[] = { 'h', 0x00E9, 0xD834, 0xDD1E, 0x20AC, 'i' };
		uint32_t mid[64];
		FB_UCHAR back[64];
		ssize_t nc = units_to_w32( orig, 6, mid, 64 );
		ssize_t nu = w32_to_units( mid, nc, back, 64 );

		chk_n( "round trip: 6 units -> 5 chars", nc, 5 );
		chk_units( "round trip: back to the same 6 units", back, nu, orig, 6 );
	}

	/* ======================================================= 8-bit (DOS) ==
	   Also never run anywhere. */
	{
		static const char src[] = { 'h', (char)0xE9, 'i' };
		static const FB_UCHAR want[] = { 'h', 0x00E9, 'i' };
		FB_UCHAR buf[64];
		ssize_t n = w8_to_units( src, 3, buf, 64 );

		/* the cast must go through UNSIGNED char: with a signed char, 0xE9
		   would sign-extend to U+FFE9 */
		chk_units( "w8 -> units is Latin-1, not sign-extended", buf, n, want, 3 );
	}
	{
		static const FB_UCHAR src[] = { 'h', 0x00E9, 0x20AC, 0xD834, 'i' };
		char buf[64];
		ssize_t n = units_to_w8( src, 5, buf, 64 );

		chk_n( "units -> w8 is one char per UNIT", n, 5 );
		g_run++;
		if( !( buf[0] == 'h' && (unsigned char)buf[1] == 0xE9 &&
		       buf[2] == '?' && buf[3] == '?' && buf[4] == 'i' ) )
		{
			g_fail++;
			printf( "FAIL units -> w8: %02X %02X %02X %02X %02X\n",
			        (unsigned char)buf[0], (unsigned char)buf[1],
			        (unsigned char)buf[2], (unsigned char)buf[3],
			        (unsigned char)buf[4] );
		}
	}

	/* ============================================== truncation behaviour ==
	   Every branch takes a capacity, and a caller that measured first will
	   never hit it -- but a short buffer must not write past the end. */
	{
		static const uint32_t src[] = { 'a', 0x1D11E, 'b' };
		FB_UCHAR buf[8];
		ssize_t n;

		memset( buf, 0x5A, sizeof( buf ) );
		n = w32_to_units( src, 3, buf, 2 );

		chk_n( "w32 short buffer still reports the full count", n, 4 );
		g_run++;
		if( !(buf[0] == 'a' && buf[1] == 0xD834 && buf[2] == 0) )
		{
			g_fail++;
			printf( "FAIL w32 truncation: %04X %04X %04X\n",
			        buf[0], buf[1], buf[2] );
		}
		g_run++;
		if( buf[3] != 0x5A5A )
		{
			g_fail++;
			printf( "FAIL w32 truncation wrote past the capacity: %04X\n", buf[3] );
		}
	}

	printf( "%d checks, %d failed\n", g_run, g_fail );
	return g_fail ? 1 : 0;
}
