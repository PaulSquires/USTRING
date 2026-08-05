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

**A `ustring` cannot be given content yet.** `dim as ustring u = "hello"` is
rejected, because mixing a ustring with a narrow string is deliberately an error
until the UTF-8 conversion path exists (`ast-node-assign.bas`,
`ast-node-bop.bas`). Rejecting is intentional — silently handing a byte buffer to
a UTF-16 runtime would corrupt data.

Compile-time literals are the right answer (zero runtime cost, matching how
`symbAllocWStrConst` handles wstring), but there is a trap in the obvious
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

So literals need one of:

1. **A dedicated union member**, e.g. `littextu as ushort ptr`, with its own
   allocator and escape helpers. Correct by construction and host-width
   independent. Most code, and touches `symb.bi`.
2. **Store as UTF-8 in `littext`** and decode to UTF-16 at emit time. Reuses the
   existing zstring literal machinery, but every backend must do the decode.
3. **Reuse `littextw`** — rejected. Works on Windows, wrong on Linux.

Option 1 is the recommendation: the whole point of the type is that its
representation does not vary by host or target, and the literal pool should not
be the one place that assumption breaks.

Backends must emit explicit `uint16` arrays for the literal pool. `L"..."` is
unusable because it is platform-width — `ir-hlc.bas` currently uses it for
wstring literals, which is the trap to avoid.

## Still owed for Phase 1

- (literals: done)
- `VAR u = <ustring expr>` inference.
- Multi-term concat optimization (`a = b + c + d` → one assign plus N
  concat-assigns). `hOptUStrAssignment` currently handles the single
  self-concat case, which is what `&=` needs, and falls back to a plain assign
  otherwise — correct, just not optimal.

## Later phases

Phase 2 is the interop matrix (the UTF-8 conversion paths, and the Windows/Linux
asymmetry when passing a ustring to `byref as wstring` — free reinterpret on
Windows, materialize plus warn on Linux). Phase 3 is the intrinsic surface,
including a generated BMP case-mapping table, since `towlower` is
locale-dependent and would reintroduce platform divergence.
