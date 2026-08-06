#!/usr/bin/env python3
"""Patch fbc 1.20's emitted LLVM IR enough for a modern clang to assemble it.

WHY THIS EXISTS

fbc's -gen llvm backend emits IR in a dialect several LLVM releases old, so a
current clang refuses it before reading a single instruction:

    error: invalid LLVM IR input: the third field of the element type is
           mandatory, specify ptr null to migrate from the obsoleted 2-field form

That is @llvm.global_ctors, and it has nothing to do with USTRING -- a plain
STRING program fails identically. Which meant the USTRING LLVM path could only
ever be checked by READING the IR, and "I read it and it looked right" is not
verification.

This rewrites only the constructs modern LLVM removed, so the ustring parts of
the IR -- the %FBUSTRING type, the literal byte arrays, the call signatures --
are assembled and RUN exactly as fbc emitted them.

NOT a general-purpose IR upgrader, and not proposed for upstream: the real fix
is for fbc's llvm backend to emit the current dialect, which is its own job.

    python tools/modernize_ll.py in.ll out.ll
"""

import re
import sys


def modernize(ir):
    # @llvm.global_ctors: the 2-field { i32, void ()* } form became the 3-field
    # { i32, ptr, ptr } form, where the third field is an associated global.
    def ctors(m):
        entries = re.findall(r'\{\s*i32,\s*void\s*\(\)\*\s*\}\s*\{\s*i32\s+(\d+),\s*void\s*\(\)\*\s*(@"[^"]+"|@[\w.$]+)\s*\}', m.group(0))
        if not entries:
            return m.group(0)
        body = ", ".join('{ i32, ptr, ptr } { i32 %s, ptr %s, ptr null }' % (p, f)
                         for p, f in entries)
        return '@llvm.global_ctors = appending global [%d x { i32, ptr, ptr }] [%s]' % (
            len(entries), body)

    ir = re.sub(r'@llvm\.global_ctors\s*=\s*appending global.*', ctors, ir)

    # Opaque pointers: LLVM 17 removed typed pointers, so every "T*" is now
    # "ptr". Applied last and only to pointer suffixes, never to multiplication
    # (fbc emits "mul" as an opcode, so a bare '*' never appears as an operator).
    # NOTE the lookbehind rather than \b: a type can start with '[' or '{',
    # which are not word characters, so \b never matches before them and array
    # types like "[16 x i8]*" would be left behind.
    ir = re.sub(r'(?<![\w.$])(?:void\s*\([^()]*\)|[%@][\w."$]+|i\d+|float|double|\[[^\[\]]*\]|\{[^{}]*\})\s*\*+',
                'ptr', ir)

    return ir


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: modernize_ll.py in.ll out.ll")
    with open(sys.argv[1], "r", encoding="utf-8", newline="") as f:
        ir = f.read()
    with open(sys.argv[2], "w", encoding="utf-8", newline="\n") as f:
        f.write(modernize(ir))


if __name__ == "__main__":
    main()
