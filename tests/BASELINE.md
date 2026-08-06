# fbc test-suite baseline (before any ustring compiler changes)

Captured against `fbc-master` with **Phase 0 only** (new rtlib files, which are not yet
reachable from any FB source) — so this is effectively the stock 1.20.0 tree.

```
1154412 assertions   1154401 passed   11 failed   2302 modules
```

## The 11 failures, and why they are not regressions

| Module | Failed | Cause |
|---|---|---|
| `fbc_tests.threads.threadcall_` | 11 / 11 | Built with `-DDISABLE_FFI` |

`libffi` is not installed in this environment, so the rtlib is built with `-DDISABLE_FFI`.
That does not remove `fb_ThreadCall` — `src/rtlib/thread_call.c:25` compiles it to
`return NULL` — so everything links, but every `ThreadCall` assertion fails. Nothing else
in the suite is affected.

**Any future run must show exactly these 11 failures and no others.** A 12th failure, or a
failure in any other module, is a regression introduced by the ustring work.

## Reproducing

Two environment workarounds are required; neither is related to ustring.

1. **Run the tests makefile directly, with native Windows paths.** The root makefile does
   ``cd tests && $(MAKE) unit-tests FBC="`pwd`/../$(FBC_EXE) -i `pwd`/../inc"``. Under Git Bash
   `pwd` yields `/c/dev/...`, which only resolves because Git Bash rewrites POSIX paths when it
   invokes a native binary. Make runs its recipes through `cmd.exe`, which does not, so fbc
   receives a literal `/c/dev/...` and every `#include` fails with `error 23: File not found`.
   Bypass it:

   ```
   cd tests && make unit-tests FBC="C:/dev/ustring/fbc-master/bin/fbc.exe -i C:/dev/ustring/fbc-master/inc"
   ```

2. **A stub `libffi.a`.** fbc emits `-lffi` whenever a `ThreadCall` appears
   (`rtl-system.bas:787`), regardless of how the rtlib was built, so the final link needs the
   name to resolve even though `DISABLE_FFI` means no ffi symbol is ever referenced:

   ```
   ar rcs lib/freebasic/win64/libffi.a <any-empty-object>
   ```

`gfxlib2` must also be built (`make gfxlib2`) — the suite links `-lfbgfxmt`.

## Trap: `clean-tests` is a ROOT makefile target

`clean-tests` is defined in `fbc-master/makefile`, **not** in `tests/Makefile`.
Running `make clean-tests` from inside `tests/` silently does nothing, and since
the `.bas` sources have not changed, make then treats all ~670 `.o` files as up
to date and re-runs the *previous* `fbc-tests.exe` unchanged.

The result looks like a passing regression run but proves nothing. To force a
real rebuild:

```
find tests -name "*.o" -delete
rm -f tests/fbc-tests.exe tests/unit-tests.inc tests/unit-tests-obj.lst
```

Confirm it actually rebuilt by checking the compile count in the log — it should
be ~670, not 1.

## The LLVM backend needs a shim, for pre-existing reasons

`fbc -gen llvm` drives `llc`, which a clang-only install does not ship, and the
IR it emits is several LLVM releases out of date. `sh tools/check_llvm.sh`
works around both and diffs the result against `-gen gcc`. None of the three
blocking constructs is ustring's — a plain `STRING` program reproduces all of
them. Details in `NOTES.md`.

## Build commands used

```
make rtlib    CFLAGS="-Wfatal-errors -O2 -fno-exceptions -fno-unwind-tables -fno-asynchronous-unwind-tables -DDISABLE_FFI"
make gfxlib2  CFLAGS="-Wfatal-errors -O2 -DDISABLE_FFI"
make compiler FBC=<bootstrap fbc 1.10.1>
```

A third environment fix lives in the tree itself: `makefile` matched `MSYS_NT` when choosing the
short `ar` command line, which missed `MINGW64_NT` and made the ~17 KB argument list overflow
`cmd.exe`'s limit. Changed to match `_NT`. That is a **separate, pre-existing bug**, not part of
the ustring feature, and should be its own upstream commit.
