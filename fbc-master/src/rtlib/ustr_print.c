/* PRINT / WRITE for ustrings
**
** WHERE THE OUTPUT GOES DECIDES THE ENCODING
**
**   real Windows console  -> the wide path, so the OS renders UTF-16 directly
**                            and fbc's cursor tracking (POS, LOCATE) stays
**                            correct
**   everything else       -> UTF-8 bytes
**
** "Everything else" is redirected output, files, and every non-Windows console.
** UTF-8 there is the point: a ustring redirected to a file must produce a
** portable file on every platform, and a Linux terminal is UTF-8 already.
**
** Note what this deliberately does NOT do: the existing wstring path writes RAW
** UTF-16 BYTES when output is redirected (win32/io_printbuff_wstr.c), which
** produces a file no other tool will read as text. A portable string type
** cannot behave that way.
*/

#include "fb.h"
#ifdef HOST_WIN32
#include "win32/fb_private_console.h"
#endif

/* TRUE when writing to a real Windows console, as opposed to a pipe or file. */
static int hIsRealConsole( int fnum )
{
#ifdef HOST_WIN32
	if( fnum != 0 )
		return 0;
	return (FB_CONSOLE_WINDOW_EMPTY() == 0);
#else
	(void)fnum;
	return 0;
#endif
}

/* NOTE the signature: (fnum, descriptor, mask), NOT the (ptr,size) pair the rest
** of the ustring API uses. The PRINT dispatch in rtl-print.bas pushes its
** arguments uniformly for every data type, so every print entry point has to
** have the same three-argument shape. A USTRING * N is converted to a temp
** descriptor by the argument handling before it arrives. */

FBCALL void fb_PrintUStr( int fnum, FBUSTRING *src, int mask )
{
	if( hIsRealConsole( fnum ) )
	{
		/* Hand the UTF-16 straight to the wide path: no conversion at all where
		   wchar_t is 16 bits, and correct cursor tracking either way. */
		FB_WCHAR *w = fb_UStrToWstr( src, FB_USTRSIZEVARLEN );
		fb_PrintWstr( fnum, w, mask );
		fb_WstrDelete( w );
	}
	else
	{
		/* fb_PrintString() releases the temp descriptor for us */
		fb_PrintString( fnum, fb_UStrToStr( src, FB_USTRSIZEVARLEN ), mask );
	}
}

FBCALL void fb_WriteUStr( int fnum, FBUSTRING *src, int mask )
{
	if( hIsRealConsole( fnum ) )
	{
		FB_WCHAR *w = fb_UStrToWstr( src, FB_USTRSIZEVARLEN );
		fb_WriteWstr( fnum, w, mask );
		fb_WstrDelete( w );
	}
	else
	{
		fb_WriteString( fnum, fb_UStrToStr( src, FB_USTRSIZEVARLEN ), mask );
	}
}
