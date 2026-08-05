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

### The rest: ASC, indexing, LSET/RSET, SWAP, numerics

`ASC` and `[]` both yield a **code unit**, so a non-ASCII BMP character reads as
its real codepoint value (`u[0]` of `"é"` is 233) — the thing a byte-oriented
string cannot do. A position holding a surrogate half yields that half.

`LSET`/`RSET` pad with spaces and never resize. `SWAP` exchanges the two
descriptors, which is O(1) and moves no text.

**The numeric intrinsics needed no ustring runtime at all.** `HEX`, `OCT`,
`BIN`, `STR` and the `VAL` family all produce or consume ASCII, so the existing
narrow versions plus UTF-8 conversion are already lossless. `VAL` only needed an
overload tiebreak — ustring→`STRING` now outranks ustring→`WSTRING`, since both
are lossless and the tie had to break somewhere. This does not affect Win32-style
APIs, whose parameters are `WSTRING PTR` and are ranked separately.

`WCHR` is how a ustring is built from a codepoint. `CHR` produces a single
*byte*, which is not valid UTF-8 above 127.

### Two bugs worth recording

**`SWAP` segfaulted under gas64.** A ustring fell through to the generic
temp-var swap (`tmp = l : l = r : r = tmp`), three full descriptor assignments,
which gas64 miscompiled. gcc happened to be fine — so this was invisible on the
default backend. Routed to `fb_UStrSwap` instead, which is both correct and
O(1).

**`LSET`/`RSET` compiled but did nothing.** `rtlStrLRSet` *emits* its call via
`astAdd()` rather than returning it, so my delegation returned a node nobody
added. The statement silently became a no-op — it compiled, ran, and changed
nothing.

`LEFT` and `RIGHT` needed two-parameter descriptor wrappers
(`fb_UStrLeftD`/`fb_UStrRightD`): they are registered as true overloads aliased
straight to a C function, so their signature is fixed and cannot carry the
`(ptr,size)` pair the rest of the API uses.

**Phase 3 is complete.**

## Phase 4 — aggregates (done), targets (partial)

UDT fields, fixed arrays and dynamic arrays all work, including deep copy: the
implicit ctor/copy-assign/dtor are generated for any UDT holding a ustring, and
`fb_ArrayDestructUStr` / `fb_ArrayUStrErase` destroy array elements.

**Two leaks were found and fixed**, both of which compiled and ran fine:

1. **The generated UDT destructor was emitted but EMPTY.** `hCallFieldDtor()`
   handled `FB_DATATYPE_STRING` but not `USTRING`, so every UDT holding a
   ustring leaked its field's buffer on every scope exit.
2. **Array scope exit emitted no destruction at all.** `rtlArrayErase`/the clear
   path had no ustring branch, so every element leaked.

Verified two ways: a descriptor-pool stress (20000 UDT scopes, 20000 array
scopes, 5000 redim/erase cycles, 5000 UDT-array scopes — a leak shows up as pool
exhaustion, which reads as length 0 rather than as a crash), and
`tests/ustring_memcheck.bas`, which allocates ~40 MB of ustring buffers across
40000 iterations and measures the working set: **16 KB growth, flat**.

### LLVM

`%FBUSTRING = type { i16*, i64, i64 }` is now emitted. Previously the IR
*referenced* the type without defining it, which llvm rejects outright.

The IR still cannot be assembled here, but for a **pre-existing** reason now
pinned down precisely: fbc 1.20's LLVM output uses an obsolete `llvm.memset`
intrinsic signature that clang 21 rejects. A plain `STRING` program with no
ustring anywhere fails identically, so this is an fbc-vs-clang version gap, not
a ustring problem.

### Targets

Only win64 can be built and run here. The 32-bit path is verified as far as code
generation goes — `-target win32` emits
`typedef struct { uint16 *data; int32 len; int32 size; } FBUSTRING;`, a 12-byte
descriptor, and computes `sizeof(ustring * 8)` as 16 — but cannot be linked
(no 32-bit assembler installed). linux64, ARM, JS and DOS are untested.

## Later phases

Phase 5 is I/O (`PRINT`, file read/write, and the console paths), Phase 6 is
upstream packaging.
