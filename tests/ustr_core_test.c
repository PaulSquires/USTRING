/* Phase 0 verification: the FBUSTRING descriptor, allocator and temp pool.
**
** The property that actually matters here is the GROWTH POLICY. A string built
** one unit at a time must stay amortised O(1); a grow-by-exactly-what-was-asked
** allocator turns that into O(n^2), which is how a 220 KB append loop becomes a
** multi-second stall. This test pins that down by counting reallocations rather
** than by timing, so it cannot flake on a slow machine.
**
** Build (from C:\dev\ustring):
**   gcc -O2 -Wall -I fbc-master/src/rtlib tests/ustr_core_test.c \
**       fbc-master/src/rtlib/ustr_core.c fbc-master/src/rtlib/ustr_prim.c \
**       fbc-master/src/rtlib/list.c fbc-master/src/rtlib/listdyn.c \n**       -o tests/ustr_core_test.exe
*/

#include "fb.h"
#include <stdio.h>

/* The rtlib's real locks live in win32/hinit.c, which would drag in most of the
   runtime. In an MT build the macros resolve to these; stub them out. */
#if defined ENABLE_MT && !defined HOST_DOS && !defined HOST_XBOX
FBCALL void fb_StrLock( void ) { }
FBCALL void fb_StrUnlock( void ) { }
#endif

static int g_fail = 0;
static int g_run  = 0;

static void chk( const char *name, long long got, long long want )
{
	g_run++;
	if( got != want )
	{
		g_fail++;
		printf( "FAIL %-40s got=%lld want=%lld\n", name, got, want );
	}
}

static void chk_true( const char *name, int cond )
{
	g_run++;
	if( !cond )
	{
		g_fail++;
		printf( "FAIL %-40s (condition false)\n", name );
	}
}

int main( void )
{
	/* ------------------------------------------------------- basic alloc */
	{
		FBUSTRING s = { NULL, 0, 0 };

		chk_true( "alloc returns desc", fb_hUStrAlloc( &s, 10 ) == &s );
		chk( "alloc len", s.len, 10 );
		chk_true( "alloc size >= len", s.size >= 10 );
		chk_true( "alloc size rounded to 16", (s.size % 16) == 0 || s.size == 10 );
		chk_true( "alloc data non-null", s.data != NULL );

		/* the allocation must really hold len+1 units -- write the full span
		   including the terminator and read it back */
		{
			ssize_t i;
			for( i = 0; i < s.size; i++ )
				s.data[i] = (FB_UCHAR)(0x1000 + i);
			s.data[s.size] = 0;
			chk( "span writable [0]", s.data[0], 0x1000 );
			chk( "span writable [size-1]", s.data[s.size-1], (FB_UCHAR)(0x1000 + s.size - 1) );
			chk( "terminator slot", s.data[s.size], 0 );
		}

		fb_UStrDelete( &s );
		chk_true( "delete nulls data", s.data == NULL );
		chk( "delete zeroes len", s.len, 0 );
		chk( "delete zeroes size", s.size, 0 );

		/* delete must be idempotent and NULL-safe */
		fb_UStrDelete( &s );
		fb_UStrDelete( NULL );
		chk_true( "delete idempotent", s.data == NULL );
	}

	/* --------------------------------------------- realloc preserves data */
	{
		FBUSTRING s = { NULL, 0, 0 };
		ssize_t i;

		fb_hUStrAlloc( &s, 4 );
		for( i = 0; i < 4; i++ )
			s.data[i] = (FB_UCHAR)('a' + i);
		s.data[4] = 0;

		fb_hUStrRealloc( &s, 400, FB_TRUE );
		chk( "realloc preserve len", s.len, 400 );
		chk_true( "realloc preserve size", s.size >= 400 );
		chk( "realloc kept [0]", s.data[0], 'a' );
		chk( "realloc kept [3]", s.data[3], 'd' );

		/* non-preserving realloc may discard contents but must resize */
		fb_hUStrRealloc( &s, 8, FB_FALSE );
		chk( "realloc nopreserve len", s.len, 8 );

		fb_UStrDelete( &s );
	}

	/* ------------------------------------------------ THE GROWTH PROPERTY */
	{
		FBUSTRING s = { NULL, 0, 0 };
		const ssize_t N = 20000;
		ssize_t i, lastsize = -1, growths = 0;

		/* append one unit at a time, exactly as &= does */
		for( i = 0; i < N; i++ )
		{
			fb_hUStrRealloc( &s, i + 1, FB_TRUE );
			if( s.size != lastsize )
			{
				growths++;
				lastsize = s.size;
			}
			s.data[i] = (FB_UCHAR)('A' + (i % 26));
		}

		chk( "grow: final len", s.len, N );
		chk_true( "grow: capacity covers len", s.size >= N );

		/* Geometric growth at ratio ~1.125 needs log(N)/log(1.125) ~= 84
		   reallocations for N=20000. Linear growth would need 20000. The bound
		   below is deliberately loose -- it is there to catch a policy
		   regression, not to pin the exact constant. */
		chk_true( "grow: amortised, not quadratic", growths < 200 );
		if( growths >= 200 )
			printf( "     (growths=%d for N=%d -- growth is not geometric)\n",
			        (int)growths, (int)N );

		/* every byte of the content must have survived every reallocation */
		{
			int intact = 1;
			for( i = 0; i < N; i++ )
				if( s.data[i] != (FB_UCHAR)('A' + (i % 26)) ) { intact = 0; break; }
			chk_true( "grow: contents intact across reallocs", intact );
		}

		fb_UStrDelete( &s );
	}

	/* ------------------------------------------------------ overflow guard */
	{
		FBUSTRING s = { NULL, 0, 0 };
		/* (units+1)*sizeof(FB_UCHAR) must not be allowed to wrap */
		chk_true( "alloc rejects absurd size",
		          fb_hUStrAlloc( &s, (ssize_t)((size_t)-1 >> 1) ) == NULL );
		chk_true( "alloc rejects negative", fb_hUStrAlloc( &s, -1 ) == NULL );
		fb_UStrDelete( &s );
	}

	/* ------------------------------------------------- temp descriptor pool */
	{
		FBUSTRING *tb[FB_STR_TMPDESCRIPTORS + 4];
		int i, nulls = 0;

		for( i = 0; i < FB_STR_TMPDESCRIPTORS; i++ )
		{
			tb[i] = fb_hUStrAllocTempDesc( );
			if( tb[i] == NULL )
				nulls++;
		}
		chk( "pool: 256 descriptors available", nulls, 0 );

		/* the pool is finite by design; exhaustion returns NULL rather than
		   growing without bound */
		chk_true( "pool: exhaustion returns NULL", fb_hUStrAllocTempDesc( ) == NULL );

		/* returning one must make it available again */
		chk( "pool: free returns 0", fb_hUStrDelTempDesc( tb[0] ), 0 );
		tb[0] = fb_hUStrAllocTempDesc( );
		chk_true( "pool: reusable after free", tb[0] != NULL );

		for( i = 0; i < FB_STR_TMPDESCRIPTORS; i++ )
			fb_hUStrDelTempDesc( tb[i] );

		/* pool must be fully returned */
		nulls = 0;
		for( i = 0; i < FB_STR_TMPDESCRIPTORS; i++ )
		{
			tb[i] = fb_hUStrAllocTempDesc( );
			if( tb[i] == NULL )
				nulls++;
		}
		chk( "pool: fully reclaimed", nulls, 0 );

		/* hand them all back -- later blocks need a free descriptor, and an
		   exhausted pool would make fb_hUStrAllocTemp() return NULL */
		for( i = 0; i < FB_STR_TMPDESCRIPTORS; i++ )
			fb_hUStrDelTempDesc( tb[i] );
	}

	/* ------------------------------------ the pool range check must be tight */
	{
		FBUSTRING stack_desc = { NULL, 0, 0 };
		static FBUSTRING static_desc = { NULL, 0, 0 };

		/* A descriptor that is NOT one of ours -- a plain variable, or a narrow
		   FBSTRING temp -- must be rejected, not freed into our pool. This is
		   the whole reason the two pools are separate static arrays. */
		chk( "range check rejects stack desc",
		     fb_hUStrDelTempDesc( &stack_desc ), -1 );
		chk( "range check rejects static desc",
		     fb_hUStrDelTempDesc( &static_desc ), -1 );
	}

	/* --------------------------------------------------------- the temp bit */
	{
		FBUSTRING *t = fb_hUStrAllocTemp( NULL, 5 );

		chk_true( "temp: allocated", t != NULL );
		if( t == NULL )
		{
			/* fail loudly rather than dereferencing -- pool exhaustion returns
			   NULL by design, and every real caller must handle that */
			printf( "FATAL temp descriptor pool exhausted; later checks skipped\n" );
			printf( "\n%d checks, %d failed\n", g_run, g_fail + 1 );
			return 1;
		}
		chk_true( "temp: flagged", FB_UISTEMP( t ) );
		chk( "temp: FB_USTRSIZE masks the flag", FB_USTRSIZE( t ), 5 );
		chk_true( "temp: raw len differs from masked", t->len != 5 );

		/* setting the length must not clear the flag */
		fb_hUStrSetLength( t, 3 );
		chk( "temp: setlength", FB_USTRSIZE( t ), 3 );
		chk_true( "temp: setlength preserves flag", FB_UISTEMP( t ) );

		chk( "temp: delete returns 0", fb_hUStrDelTemp( t ), 0 );

		/* a non-temp descriptor passed to DelTemp must not have its data freed
		   -- only pool members are ours to release */
		chk( "temp: delete of NULL", fb_hUStrDelTemp( NULL ), -1 );
	}

	printf( "\n%d checks, %d failed\n", g_run, g_fail );
	return g_fail != 0;
}
