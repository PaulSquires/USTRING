/* ustring <-> wstring conversion
**
** THE ASYMMETRY THIS FILE EXISTS FOR
**
** A ustring code unit is 16 bits on every target. FB_WCHAR is wchar_t: 16 bits
** on Windows, 32 on Linux, 8 on DOS. So:
**
**   Windows  ustring and wstring are the same representation. Copying is a
**            memcpy, and at the call boundary the compiler can hand out the
**            buffer pointer directly with no conversion at all.
**   Linux    every character has to be re-encoded, UTF-16 <-> UTF-32, into a
**            fresh buffer.
**   DOS      FB_WCHAR is char (DISABLE_WCHAR); treated as Latin-1, which is the
**            most that target can represent.
**
** The branches below are on sizeof(FB_WCHAR) and fold away at compile time.
** They are NOT #ifdefs on the platform: the width is the thing that matters,
** and stating it that way keeps the three cases visible together.
*/

#include "fb.h"

/* wstring -> ustring, into a caller-provided buffer sized by the measure pass.
   Returns units written (excluding the terminator); dst may be NULL to measure. */
static ssize_t hWcharToUnits( const FB_WCHAR *src, ssize_t src_chars,
                              FB_UCHAR *dst, ssize_t dst_units )
{
	if( sizeof( FB_WCHAR ) == 2 )
	{
		/* already UTF-16, including any surrogate pairs */
		ssize_t n = src_chars;
		if( dst != NULL )
		{
			ssize_t i, lim = (n < dst_units) ? n : dst_units;
			for( i = 0; i < lim; i++ )
				dst[i] = (FB_UCHAR)src[i];
			dst[lim] = 0;
		}
		return n;
	}
	else if( sizeof( FB_WCHAR ) == 4 )
	{
		/* UTF-32 -> UTF-16; a scalar above the BMP becomes a surrogate pair,
		   so the unit count is NOT the character count */
		ssize_t i, n = 0;
		for( i = 0; i < src_chars; i++ )
		{
			uint32_t cp = (uint32_t)src[i];
			if( (cp > FB_UCHAR_MAX_CP) || FB_UCHAR_IS_SUR( cp ) )
				cp = FB_UCHAR_REPLACEMENT;

			if( cp < 0x10000u )
			{
				if( (dst != NULL) && (n < dst_units) ) dst[n] = (FB_UCHAR)cp;
				n++;
			}
			else
			{
				if( (dst != NULL) && (n < dst_units) ) dst[n] = FB_UCHAR_CP_HIGHSUR( cp );
				n++;
				if( (dst != NULL) && (n < dst_units) ) dst[n] = FB_UCHAR_CP_LOWSUR( cp );
				n++;
			}
		}
		if( dst != NULL )
			dst[(n < dst_units) ? n : dst_units] = 0;
		return n;
	}
	else
	{
		/* DOS: FB_WCHAR is char. Latin-1 is the best this target can do. */
		ssize_t i, n = src_chars;
		if( dst != NULL )
		{
			ssize_t lim = (n < dst_units) ? n : dst_units;
			for( i = 0; i < lim; i++ )
				dst[i] = (FB_UCHAR)(unsigned char)src[i];
			dst[lim] = 0;
		}
		return n;
	}
}

/* ustring -> wstring. Returns chars written (excluding the terminator). */
static ssize_t hUnitsToWchar( const FB_UCHAR *src, ssize_t src_units,
                              FB_WCHAR *dst, ssize_t dst_chars )
{
	if( sizeof( FB_WCHAR ) == 2 )
	{
		ssize_t n = src_units;
		if( dst != NULL )
		{
			ssize_t i, lim = (n < dst_chars) ? n : dst_chars;
			for( i = 0; i < lim; i++ )
				dst[i] = (FB_WCHAR)src[i];
			dst[lim] = 0;
		}
		return n;
	}
	else if( sizeof( FB_WCHAR ) == 4 )
	{
		/* UTF-16 -> UTF-32: a surrogate pair collapses into one char */
		ssize_t i = 0, n = 0;
		while( i < src_units )
		{
			ssize_t used;
			uint32_t cp = fb_hUStrCodepointAt( src, src_units, i, &used );
			if( (dst != NULL) && (n < dst_chars) ) dst[n] = (FB_WCHAR)cp;
			n++;
			i += used;
		}
		if( dst != NULL )
			dst[(n < dst_chars) ? n : dst_chars] = 0;
		return n;
	}
	else
	{
		/* DOS: anything outside Latin-1 cannot be represented */
		ssize_t i, n = src_units;
		if( dst != NULL )
		{
			ssize_t lim = (n < dst_chars) ? n : dst_chars;
			for( i = 0; i < lim; i++ )
				dst[i] = (FB_WCHAR)((src[i] < 256) ? src[i] : '?');
			dst[lim] = 0;
		}
		return n;
	}
}

/* --------------------------------------------------------------- assignment */

FBCALL void *fb_UStrAssignFromW
	(
		void *dst,
		ssize_t dst_size,
		const FB_WCHAR *src,
		int fill_rem,
		int is_init
	)
{
	ssize_t src_chars, units;
	FB_UCHAR *tmp;

	if( dst == NULL )
		return dst;

	src_chars = (src != NULL) ? (ssize_t)fb_wstr_Len( src ) : 0;

	units = hWcharToUnits( src, src_chars, NULL, 0 );

	tmp = (FB_UCHAR *)malloc( (units + 1) * sizeof( FB_UCHAR ) );
	if( tmp == NULL )
		return dst;

	hWcharToUnits( src, src_chars, tmp, units );

	fb_UStrAssignEx( dst, dst_size, tmp, (units | FB_STRISFIXED), fill_rem, is_init );

	free( tmp );

	return dst;
}

FBCALL FB_WCHAR *fb_UStrAssignToW
	(
		FB_WCHAR *dst,
		ssize_t dst_chars,
		void *src,
		ssize_t src_size
	)
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len, n;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	if( dst != NULL )
	{
		/* dst_chars is the declared capacity INCLUDING the terminator, matching
		   how the compiler passes WSTRING * N lengths */
		ssize_t cap = (dst_chars > 0) ? (dst_chars - 1) : src_len;
		n = hUnitsToWchar( src_ptr, src_len, dst, cap );
		(void)n;
	}

	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );

	FB_STRUNLOCK();

	return dst;
}

/* -------------------------------------------------- expression conversions */

FBCALL FBUSTRING *fb_WstrToUStr( const FB_WCHAR *src )
{
	FBUSTRING *dst;
	ssize_t src_chars, units;

	FB_STRLOCK();

	src_chars = (src != NULL) ? (ssize_t)fb_wstr_Len( src ) : 0;
	units = hWcharToUnits( src, src_chars, NULL, 0 );

	dst = fb_hUStrAllocTemp_NoLock( NULL, units );
	if( dst != NULL )
	{
		if( dst->data != NULL )
			hWcharToUnits( src, src_chars, dst->data, units );
	}
	else
	{
		dst = &__fb_ctx.unull_desc;
	}

	FB_STRUNLOCK();

	return dst;
}

/* ustring -> a freshly allocated wchar buffer.
**
** The caller frees it with fb_WstrDelete(), matching every other wstring-
** returning rtlib function. On Windows this still allocates -- the compiler
** avoids calling this at all where it can hand out the buffer directly. */
FBCALL FB_WCHAR *fb_UStrToWstr( void *src, ssize_t src_size )
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len, chars;
	FB_WCHAR *dst;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	chars = hUnitsToWchar( src_ptr, src_len, NULL, 0 );

	dst = (FB_WCHAR *)malloc( (chars + 1) * sizeof( FB_WCHAR ) );
	if( dst != NULL )
		hUnitsToWchar( src_ptr, src_len, dst, chars );

	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );

	FB_STRUNLOCK();

	return dst;
}
