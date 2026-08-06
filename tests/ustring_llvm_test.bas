'' The USTRING pieces of the -gen llvm backend, kept deliberately small.
''
'' fbc 1.20's llvm backend emits IR in a dialect several LLVM releases old --
'' obsolete @llvm.global_ctors, typed pointers, and more. None of that is
'' USTRING's doing (a plain STRING program fails identically), but it did mean
'' the ustring LLVM path could only ever be checked by READING the IR.
''
'' This file is small on purpose: small enough that tools/modernize_ll.py can
'' carry it to a modern clang, so the ustring-specific IR -- the %FBUSTRING type
'' definition, the literal byte arrays, and the runtime call signatures -- is
'' actually ASSEMBLED AND RUN rather than eyeballed.
''
'' It prints one line per check. Compare against the same program built with
'' -gen gcc; see NOTES.md for the pipeline.

dim as ustring a = "hello"
dim as ustring b = " world"
dim as ustring c = a + b

print "concat="; c
print "len="; len(c)

'' Literals are emitted as escaped little-endian bytes in the llvm backend, so
'' a non-ASCII one is the case that would expose a width mistake.
dim as ustring e = wchr(&h20AC)      '' euro sign
print "euro_len="; len(e)
print "euro_unit="; e[0]

'' NOTE the absence of a USTRING * N here. fbc's llvm backend emits a CONSTANT
'' EXPRESSION bitcast of a function-local alloca for any fixed-length local:
''
''   %vr97 = bitcast i16* bitcast ([16 x i8]* %F.8 to i16*) to i8*
''
'' which modern LLVM rejects ("invalid use of function-local name"). WSTRING * N
'' and ZSTRING * N emit the identical construct, so it is a pre-existing backend
'' bug and not USTRING's -- but it does mean the fixed form cannot be assembled
'' here, so it is left to the gcc and gas64 suites, which do cover it.

print "upper="; ucase(c)
print "mid="; mid(c, 7, 5)
print "instr="; instr(c, "world")

dim as string narrow = c
print "narrow_bytes="; len(narrow)
