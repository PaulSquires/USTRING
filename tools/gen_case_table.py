#!/usr/bin/env python3
"""Generate src/rtlib/ustr_casetable.c -- simple case mappings over the BMP.

WHY A TABLE AT ALL

The obvious implementation is towlower()/towupper(). They are unusable here:
they are locale-dependent, so the same ustring would fold differently depending
on the user's locale and on which libc the program was linked against. That is
exactly the platform divergence USTRING exists to remove.

WHAT IS GENERATED

SIMPLE case mapping only -- one code unit in, one code unit out. Python's
str.upper()/str.lower() perform FULL case mapping, which can produce more than
one character (German sharp s upper-cases to "SS", for example). Those are
skipped: a one-to-many mapping cannot be expressed by an in-place unit
transform, and FB's UCASE/LCASE have never done it for any other string type.

Mappings are emitted as [lo, hi, delta] runs rather than pairs, which cuts
~1170 entries down to ~660 per direction.

Regenerate with:
    python tools/gen_case_table.py > fbc-master/src/rtlib/ustr_casetable.c
"""

import sys
import unicodedata


def build(mapper):
    """Return [(lo, hi, delta)] runs for a simple case mapping over the BMP."""
    pairs = []
    for cp in range(0x10000):
        c = chr(cp)
        m = mapper(c)
        # single code point only -- see the note about full case mapping above
        if len(m) == 1 and m != c:
            t = ord(m)
            # and the result must itself be in the BMP, since a ustring code
            # unit is 16 bits
            if t < 0x10000:
                pairs.append((cp, t))

    runs = []
    for cp, t in pairs:
        d = t - cp
        if runs and runs[-1][1] == cp - 1 and runs[-1][2] == d:
            runs[-1][1] = cp
        else:
            runs.append([cp, cp, d])
    return runs


def emit(name, runs, out):
    out.write("static const FB_UCASE_RUN %s[] = {\n" % name)
    for lo, hi, d in runs:
        out.write("\t{ 0x%04X, 0x%04X, %6d },\n" % (lo, hi, d))
    out.write("};\n\n")


def main():
    upper = build(str.upper)
    lower = build(str.lower)

    out = sys.stdout
    out.write("/* GENERATED FILE -- do not edit by hand.\n")
    out.write("**\n")
    out.write("** Simple case mappings over the BMP, for UCASE/LCASE on USTRING.\n")
    out.write("** Regenerate with:  python tools/gen_case_table.py > src/rtlib/ustr_casetable.c\n")
    out.write("**\n")
    out.write("** Source: Python unicodedata %s (Unicode %s).\n"
              % (sys.version.split()[0], unicodedata.unidata_version))
    out.write("**\n")
    out.write("** NOT towlower()/towupper(): those are locale-dependent, so the same\n")
    out.write("** ustring would fold differently depending on the user's locale and libc.\n")
    out.write("** A ustring must behave identically everywhere.\n")
    out.write("**\n")
    out.write("** SIMPLE mappings only -- one unit in, one unit out. Full case mapping can\n")
    out.write("** produce more than one character, which an in-place unit transform cannot\n")
    out.write("** express and which no other FB string type does either.\n")
    out.write("*/\n\n")
    out.write('#include "fb.h"\n\n')
    out.write("typedef struct { uint16_t lo, hi; int32_t delta; } FB_UCASE_RUN;\n\n")

    emit("__fb_ucase_upper", upper, out)
    emit("__fb_ucase_lower", lower, out)

    out.write("""static FB_UCHAR hLookup( const FB_UCASE_RUN *tb, int n, FB_UCHAR c )
{
\tint lo = 0, hi = n - 1;

\twhile( lo <= hi )
\t{
\t\tint mid = lo + ((hi - lo) >> 1);
\t\tif( c < tb[mid].lo )
\t\t\thi = mid - 1;
\t\telse if( c > tb[mid].hi )
\t\t\tlo = mid + 1;
\t\telse
\t\t\treturn (FB_UCHAR)((int32_t)c + tb[mid].delta);
\t}

\treturn c;
}

/* Surrogates are deliberately left alone: a lone half has no case, and mapping
   the halves of a pair independently would corrupt the character. Case mapping
   above the BMP is not supported, matching the "simple mapping" contract. */
FB_UCHAR fb_hUStrToUpper( FB_UCHAR c )
{
\tif( FB_UCHAR_IS_SUR( c ) )
\t\treturn c;
\treturn hLookup( __fb_ucase_upper,
\t                (int)(sizeof(__fb_ucase_upper)/sizeof(__fb_ucase_upper[0])), c );
}

FB_UCHAR fb_hUStrToLower( FB_UCHAR c )
{
\tif( FB_UCHAR_IS_SUR( c ) )
\t\treturn c;
\treturn hLookup( __fb_ucase_lower,
\t                (int)(sizeof(__fb_ucase_lower)/sizeof(__fb_ucase_lower[0])), c );
}
""")


if __name__ == "__main__":
    main()
