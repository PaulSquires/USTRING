# USTRING implementation notes

Status and open decisions. See `tests/BASELINE.md` for the test baseline and the
environment workarounds this machine needs.

## Working now

`dim as ustring u` and `dim as ustring * N u` declare, assign, concatenate,
compare, report `LEN`, and destroy correctly. Generated C for a scope:

```c
FBUSTRING A$1;  __builtin_memset( &A$1, 0, 24ll );
FBUSTRING B$1;  __builtin_memset( &B$1, 0, 24ll );
FBUSTRING C$1;  __builtin_memset( &C$1, 0, 24ll );
__builtin_memset( &TMP$2$1, 0, 24ll );
FBUSTRING* vr$7 = fb_UStrConcat( &TMP$2$1, (void*)&A$1, -1ll, (void*)&B$1, -1ll );
fb_UStrAssign( (void*)&C$1, -1ll, (void*)vr$7, -1ll, 0 );
fb_UStrDelete( (FBUSTRING*)&C$1 );
fb_UStrDelete( (FBUSTRING*)&B$1 );
fb_UStrDelete( (FBUSTRING*)&A$1 );
```

`-1` is `FB_USTRSIZEVARLEN`, the var-len descriptor sentinel.

## Literals — done

`dim as ustring u = "hello"` works. Literals are converted at compile time, so
there is no runtime cost:

```c
fb_UStrInit( (void*)&U$0, -1ll,
             (void*)(uint16[]){0x0068,0x0065,0x006C,0x006C,0x006F,0x0000},
             -9223372036854775803ll, 0 );
```

(The size is `FB_STRISFIXED | 5`.)

Storage is a dedicated `littextu as ushort ptr` union member holding **raw
UTF-16 code units** — not escaped text like the z/wstring literals, so there is
no escape/unescape round trip to get wrong. `symbAllocUstrConst()` names the
symbol `{fbuc}` + hex of the units, which gives exact de-duplication.

Both lexer paths are covered and produce identical results, which cross-checks
the two decoders against each other:

| Source | Literal dtype | Path |
|---|---|---|
| no BOM | `CHAR` | bytes read as UTF-8 → `hUtf8ToUstr()` |
| UTF-8 BOM | `WCHAR` | host wchar → `hHostWstrToUstr()` |

The second is why the dedicated union member matters: the lexer decodes into the
**host** compiler's wchar width (fbc is self-hosted), 2 bytes on Windows and 4 on
Linux, so that path has to normalize. Reusing `littextw` would have stored
UTF-16 on one host and UTF-32 on the other.

### Backend literal emission

Each backend needs its own form, because none of the existing ones is
width-correct:

- **gcc** (`ir-hlc.bas`) — a C99 compound literal `(uint16[]){0x0068,…}`.
  Not `L"…"` (wchar_t-width) and not `"…"` (byte-oriented: a 16-bit unit's high
  NUL byte terminates it early — the first attempt emitted `"h\x00llo"`).
- **gas64** (`ir-gas64.bas`) — `.short 0x0068,…`. `.ascii` has the same
  early-termination problem.
- **llvm** (`ir-llvm.bas`) — escaped little-endian bytes,
  `[12 x i8] c"\68\00\65\00\6C\00\6C\00\6F\00\00\00"`. **Verified by inspecting
  the IR only** — `llc` is unavailable here, so it has never been assembled.

## Historical: why literals needed a storage decision

*Kept because the reasoning still governs anything else that stores ustring text.
Option 1 below is what was implemented.*

Compile-time literals were the obvious answer (zero runtime cost, matching how
`symbAllocWStrConst` handles wstring), but there was a trap in the obvious
implementation:

`FBS_VAR` stores literal text in a union of `littext as zstring ptr` /
`littextw as wstring ptr` (`symb.bi`). Reusing `littextw` for ustring literals
would work on Windows, where `wstring` is 2 bytes and therefore happens to match
a code unit — and would silently store the wrong width on Linux, where `wstring`
is 4 bytes.

That is precisely the class of bug USTRING exists to eliminate, and it would be
invisible to anyone developing on Windows. **fbc is self-hosted, so the width in
question is the HOST compiler's `wstring`, not the target's** — the same hazard
`env.wcharconv` already guards for wstring literal folding (`fb.bas:492`), and
which `hUnescapeW` still gets wrong (`hlp-str.bas`, it splits surrogates on host
width).

The three options were:

1. **A dedicated union member**, `littextu as ushort ptr`, with its own
   allocator. Correct by construction and host-width independent. **Chosen.**
2. **Store as UTF-8 in `littext`** and decode to UTF-16 at emit time. Reuses the
   existing zstring literal machinery, but every backend must do the decode.
3. **Reuse `littextw`** — rejected. Works on Windows, wrong on Linux.

Option 1 won because the whole point of the type is that its representation does
not vary by host or target, and the literal pool should not be the one place
that assumption breaks.

## VAR inference and multi-term concat — done

`VAR` infers the **dynamic** form from any ustring expression, including from a
`USTRING * N` — the N has nowhere to live on an expression dtype, and leaving it
fixed would produce a one-code-unit variable. Mirrors `zstring`/`STRING * N`
inferring to `STRING`.

Fixing this exposed a separate bug: `LEN` on a `USTRING * N` returned the
**capacity** rather than the text length, because `FB_USTRSETUP` took the length
from the size argument. The size carries the capacity (writers need it); readers
must walk to the terminator. `USTRING * N` follows `WSTRING * N` here, not
`STRING * N` — the latter space-pads, so its `LEN` genuinely is its capacity.

Multi-term concatenation lowers to one assign plus N concat-assigns, so nothing
is allocated per term. `u = a + b + c + d` emits:

```c
fb_UStrAssign      ( (void*)&U$0, -1ll, (void*)&A$0, -1ll, 0 );
fb_UStrConcatAssign( (void*)&U$0, -1ll, (void*)&B$0, -1ll, 0 );
fb_UStrConcatAssign( (void*)&U$0, -1ll, (void*)&C$0, -1ll, 0 );
fb_UStrConcatAssign( (void*)&U$0, -1ll, (void*)&D$0, -1ll, 0 );
```

Zero `fb_UStrConcat` calls, so zero temp descriptors.

This reuses `hOptStrMultConcat()`, which previously carried an `is_wstr` boolean
and branched on it at six points. A third string type does not fit a boolean, so
it now takes a dtype and dispatches through `hMultStrAssign()` /
`hMultStrConcatAssign()`. That is a change to code STRING and WSTRING both use —
verified by the full suite staying at 1154412 assertions, and by checking
directly that `s = a + b + c + d` on a STRING still emits one `fb_StrAssign`
plus three `fb_StrConcatAssign` and no `fb_StrConcat`.

A fixed-length destination is excluded from the rewrite, as `STRING * N` is: it
cannot grow, so the rewrite buys nothing.

**Phase 1 is complete.**

## Phase 2 — narrow interop, procedures (in progress)

Done: `STRING`/`ZSTRING` ↔ `USTRING` assignment, mixed concatenation in both
orders, cross-type comparison, `BYREF`/`BYVAL` parameters, and `FUNCTION … AS
USTRING`. Conversion is UTF-8 both ways with U+FFFD for malformed input, so it
is identical on every target — unlike `STRING` ↔ `WSTRING`, which goes through
the C locale.

Three bugs found by testing rather than by reading, all of which produced
plausible-looking output:

1. **`BYVAL` did not copy.** A ustring is non-trivial, so it always travels by
   address; without a temp copy the callee edited the caller's variable.
   `hAllocTempUString()` supplies the copy, mirroring `hAllocTempString()`.
2. **Discarded results leaked a pooled temp descriptor.** Only 256 exist, so a
   loop ignoring results exhausted the pool and every later call returned the
   null descriptor — reading as length 0, not as a crash. `ast-node-call.bas`
   now releases them.
3. **Multi-term concat corrupted mixed operands.** `hOptStrMultConcat` splits
   into per-operand appends and dispatched on the *destination* dtype, so a
   narrow operand was appended as raw code units: `"he"` became U+6568.
   `hMultStrConcatAssign()` decodes it first.

### wstring interop, overloads, copy-back

**`WSTRING` ↔ `USTRING`** in both directions, plus mixed concatenation and
comparison. The runtime branches on `sizeof(FB_WCHAR)`, so it is a copy where
wchar_t is 16 bits and a real UTF-16 ↔ UTF-32 re-encode where it is 32.

**The asymmetry the type was designed around** now shows up where it matters —
passing a ustring to a `WSTRING PTR` parameter:

```c
TAKEPTR( (uint16*)*(uint16**)&U$0 );   // Windows: pure reinterpret, no call
```

Zero conversion calls. Where wchar_t is wider there is no pointer to hand out,
so the compiler re-encodes **and warns** (`FB_WARNINGMSG_USTRTOWSTRCOPY`) — the
cost is invisible to anyone developing on Windows otherwise.

`USTRING` → `ZSTRING PTR` is deliberately a *mismatch* rather than a silent
conversion: a pointer needs a buffer of the right element width, and a ustring's
is 16-bit.

**Overload resolution.** All three string types share `FB_DATACLASS_STRING`, so
every call with more than one of them in scope was ambiguous. Ranking added in
`symbCalcArgMatch`: an exact family match outranks a cross-family one, a zstring
literal prefers `STRING`, and a wstring prefers `USTRING` (both are UTF-16, so
nothing is lost).

**Copy-back.** `BYREF` through a converting parameter writes the result back, or
`BYREF` is a lie for every non-ustring argument. The subtle part: the decision
has to be made *before* the conversion runs, because the conversion replaces the
argument with a CALL and the `astIsCALL` exclusion would then disable copy-back
for exactly the arguments that need it.

**Phase 2 is complete.**

## Phase 3 — intrinsics (core done)

`LEFT`, `RIGHT`, `MID` (function and statement), `INSTR`, `INSTRREV` (+`ANY`),
`TRIM`/`LTRIM`/`RTRIM` (+`ANY`/`EX`), `UCASE`, `LCASE`, `SPACE`, `STRING()`.

Positions and lengths are **code units**, 1-based. Searching by code unit is
safe for UTF-16 without any surrogate awareness: a surrogate half can never
equal a BMP unit, so a match cannot land mid-character — the thing a naive byte
search over UTF-8 would get wrong.

### The case table

`towupper`/`towlower` are unusable: they are locale-dependent, so the same
ustring would fold differently depending on the user's locale and on which libc
the program linked against. That is the platform divergence this type exists to
remove.

`tools/gen_case_table.py` generates `src/rtlib/ustr_casetable.c` from Python's
`unicodedata` (Unicode 15.1.0), as `[lo, hi, delta]` runs — ~660 runs per
direction instead of ~1170 pairs, binary searched. **Simple** mappings only: one
unit in, one out. Full case mapping can produce more than one character (German
sharp s upper-casing to `SS`), which an in-place unit transform cannot express
and which no other FB string type does either.

Surrogates are left alone. Mapping the halves of a pair independently would
corrupt the character, so an astral character passes through `UCASE` unchanged.

Verified for Latin-1 accents, Greek and Cyrillic, plus astral and CJK
pass-through.

### Still owed in Phase 3

`LSET`/`RSET`, `SWAP`, `ASC`/`CHR`, the `VAL` family, `HEX`/`OCT`/`BIN`,
`STR`/`USTR`, `[]` indexing and `STRPTR`/`SADD`.

`LEFT` and `RIGHT` needed two-parameter descriptor wrappers
(`fb_UStrLeftD`/`fb_UStrRightD`): they are registered as true overloads aliased
straight to a C function, so their signature is fixed and cannot carry the
`(ptr,size)` pair the rest of the API uses.

## Later phases

Phase 4 is aggregates and the remaining backends, Phase 5 I/O, Phase 6 upstream
packaging.
