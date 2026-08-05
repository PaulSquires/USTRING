'' DRAW STRING for USTRING.
''
'' gfxlib2's font is a 256-glyph bitmap indexed by BYTE, and gfxlib2 declares
'' its charset as CP437 (fb_gfx.h, FB_GFX_GET_CHARSET). So one code unit must
'' become one CP437 byte -- and therefore one glyph.
''
'' Before this was wired, a ustring silently satisfied the narrow 'byref as
'' const string' parameter, converting to UTF-8. Every non-ASCII character then
'' drew two or three garbage glyphs, because the font indexes bytes.
''
'' These tests do not eyeball anything: they render the ustring and the
'' equivalent narrow string to the same surface and compare the PIXELS.

#include once "fbgfx.bi"

dim shared as integer g_run, g_fail
dim shared as integer g_log

sub chk( byref nm as string, byval got as longint, byval want as longint )
    g_run += 1
    if( got <> want ) then
        g_fail += 1
        print #g_log, "FAIL " & nm & " got=" & got & " want=" & want
    end if
end sub

screenres 640, 100, 32

g_log = freefile
open "ustring_gfx_test.out" for output as #g_log

'' Grab the drawn pixels of a row as a packed signature.
function rowsig( byval h as integer ) as string
    dim as string sig
    for y as integer = 0 to h - 1
        for x as integer = 0 to 319
            sig += iif( (point(x, y) and &hFFFFFF) <> 0, "#", "." )
        next
    next
    return sig
end function

'' ------------------------------------------------ ASCII matches STRING exactly
dim as string  ns = "Hello, World!"
dim as ustring us = "Hello, World!"

cls
draw string (0, 0), ns, rgb(255,255,255)
dim as string sig_narrow = rowsig(16)

cls
draw string (0, 0), us, rgb(255,255,255)
dim as string sig_ustr = rowsig(16)

chk( "ASCII renders identically to STRING", len(sig_narrow) > 0 andalso sig_narrow = sig_ustr, -1 )
chk( "ASCII actually drew something", instr(sig_narrow, "#") > 0, -1 )

'' -------------------------------------- a CP437 character draws its OWN glyph
'' U+0398 GREEK CAPITAL THETA is CP437 byte &hE9. Drawing the ustring must
'' produce the same pixels as drawing chr(&hE9) -- one glyph, not two.
cls
draw string (0, 0), chr(&hE9), rgb(255,255,255)
dim as string sig_theta_byte = rowsig(16)

dim as ustring uth = wchr(&h0398)
chk( "theta is 1 code unit", len(uth), 1 )
cls
draw string (0, 0), uth, rgb(255,255,255)
dim as string sig_theta_ustr = rowsig(16)

chk( "U+0398 draws CP437 byte &hE9", sig_theta_byte = sig_theta_ustr, -1 )
chk( "theta glyph is not blank", instr(sig_theta_byte, "#") > 0, -1 )

'' The regression this fixes: UTF-8 would have been 2 bytes, so 2 glyphs.
'' Confirm the ustring is NOT drawn as its UTF-8 bytes.
dim as string th_utf8 = uth        '' ustring -> string is UTF-8
chk( "theta is 2 bytes in UTF-8", len(th_utf8), 2 )
cls
draw string (0, 0), th_utf8, rgb(255,255,255)
dim as string sig_theta_utf8 = rowsig(16)
chk( "UTF-8 bytes draw something DIFFERENT", sig_theta_utf8 <> sig_theta_ustr, -1 )

'' ------------------------------------------- a character the font cannot show
'' U+4E2D has no CP437 glyph, so it becomes a single '?'.
cls
draw string (0, 0), "?", rgb(255,255,255)
dim as string sig_q = rowsig(16)

cls
draw string (0, 0), wchr(&h4E2D), rgb(255,255,255)
chk( "unmappable BMP char -> one '?'", rowsig(16) = sig_q, -1 )

'' An astral character is 2 code units but ONE character, so it must not
'' become two '?'.
dim as ustring astral = wchr(&h1D11E)
chk( "astral is 2 code units", len(astral), 2 )
cls
draw string (0, 0), astral, rgb(255,255,255)
chk( "surrogate pair -> one '?', not two", rowsig(16) = sig_q, -1 )

'' ------------------------------------------------------ USTRING * N and empty
dim as ustring * 16 uf = "Fixed"
cls
draw string (0, 0), "Fixed", rgb(255,255,255)
dim as string sig_fixed_narrow = rowsig(16)
cls
draw string (0, 0), uf, rgb(255,255,255)
chk( "USTRING * N renders identically", rowsig(16) = sig_fixed_narrow, -1 )

dim as ustring empty
cls
draw string (0, 0), empty, rgb(255,255,255)
chk( "empty ustring draws nothing", instr(rowsig(16), "#"), 0 )

'' ---------------------------------------------------------- mixed ASCII + CP437
dim as ustring mixed = "a" + wchr(&h0398) + "b"
cls
draw string (0, 0), "a" + chr(&hE9) + "b", rgb(255,255,255)
dim as string sig_mixed_narrow = rowsig(16)
cls
draw string (0, 0), mixed, rgb(255,255,255)
chk( "mixed ASCII + CP437 matches byte-for-byte", rowsig(16) = sig_mixed_narrow, -1 )

print #g_log, g_run & " checks, " & g_fail & " failed"
close #g_log

if( g_fail <> 0 ) then end 1
