# REQUIRES: ppc
## R_PPC64_TOC16 is a signed displacement from the TOC pointer (r2). Values in
## [0x8000, 0xffff] must be rejected: written into a D-form instruction they
## would silently address the TOC base minus 32 KiB or more.

# RUN: llvm-mc -filetype=obj -triple=ppc64 %s -o %t.o
# RUN: echo 'SECTIONS { .text 0x1000 : { *(.text) } .got 0x10000 : { *(.got) } }' > %t.lds

## The TOC base is .got + 0x8000 = 0x18000.
# RUN: ld.lld -T %t.lds %t.o --defsym=a=0x1fffc -o %t1
# RUN: llvm-objdump -d --no-show-raw-insn %t1 | FileCheck %s --check-prefix=MAX
# MAX: lwz 3, 32764(2)
# RUN: ld.lld -T %t.lds %t.o --defsym=a=0x10000 -o %t2
# RUN: llvm-objdump -d --no-show-raw-insn %t2 | FileCheck %s --check-prefix=MIN
# MIN: lwz 3, -32768(2)

# RUN: not ld.lld -T %t.lds %t.o --defsym=a=0x20000 -o /dev/null 2>&1 | \
# RUN:   FileCheck %s --check-prefix=ERR -DV=32768
# RUN: not ld.lld -T %t.lds %t.o --defsym=a=0x27ffc -o /dev/null 2>&1 | \
# RUN:   FileCheck %s --check-prefix=ERR -DV=65532
# RUN: not ld.lld -T %t.lds %t.o --defsym=a=0xfffc -o /dev/null 2>&1 | \
# RUN:   FileCheck %s --check-prefix=ERR -DV=-32772
# ERR: error: {{.*}}:(.text+0x2): relocation R_PPC64_TOC16 out of range: [[V]] is not in [-32768, 32767]

.globl _start
_start:
  lwz 3, a@toc(2)
