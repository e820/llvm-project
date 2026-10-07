# REQUIRES: ppc
## CellOS Lv-2 (PS3 PPU) is 64-bit PowerPC with 8-byte function descriptors,
## {u32 entry, u32 TOC base}, whose TOC word is an R_PPC64_ADDR32 against
## .TOC.. Direct calls branch to the ".foo" entry symbols. The output keeps the
## Lv-2 OS/ABI and leaves e_flags clear.

# RUN: rm -rf %t && split-file %s %t && cd %t
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-lv2 a.s -o a.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-lv2 b.s -o b.o
# RUN: ld.lld -e ._start a.o b.o -o out
# RUN: llvm-readelf -h -s out > dump.txt
# RUN: llvm-objdump -d --no-show-raw-insn -s -j .text -j .opd -j .toc out >> dump.txt
# RUN: FileCheck %s < dump.txt

# CHECK:      OS/ABI: 66
# CHECK:      Flags: 0x0

# CHECK-DAG:  [[#%x,TOC:]] 0 NOTYPE LOCAL HIDDEN {{.*}} .TOC.
# CHECK-DAG:  [[#%x,START_DESC:]] 0 NOTYPE GLOBAL DEFAULT {{.*}} _start
# CHECK-DAG:  [[#%x,START:]] 0 FUNC GLOBAL DEFAULT {{.*}} ._start
# CHECK-DAG:  [[#%x,CALLEE_DESC:]] 0 NOTYPE GLOBAL DEFAULT {{.*}} callee
# CHECK-DAG:  [[#%x,CALLEE:]] 0 FUNC GLOBAL DEFAULT {{.*}} .callee

## The TOC entry holds the address of callee's descriptor.
# CHECK:      Contents of section .toc:
# CHECK-NEXT: [[#%x,]] [[#%.8x,CALLEE_DESC]]
## Each descriptor holds the entry point and the TOC base.
# CHECK:      Contents of section .opd:
# CHECK-NEXT: [[#%x,START_DESC]] [[#%.8x,START]] [[#%.8x,TOC]] [[#%.8x,CALLEE]] [[#%.8x,TOC]]

# CHECK:      <._start>:
# CHECK-NEXT: bl 0x[[#CALLEE]] <.callee>
# CHECK-NEXT: nop

#--- a.s
  .section .opd,"aw",@progbits
  .p2align 3
  .globl _start
_start:
  .long ._start
  .long .TOC.

  .text
  .globl ._start
  .type ._start,@function
._start:
  bl .callee
  nop
  addis 3, 2, .LC0@toc@ha
  lwz 3, .LC0@toc@l(3)
  blr

  .section .toc,"aw",@progbits
  .p2align 2
.LC0:
  .long callee

#--- b.s
  .section .opd,"aw",@progbits
  .p2align 3
  .globl callee
callee:
  .long .callee
  .long .TOC.

  .text
  .globl .callee
  .type .callee,@function
.callee:
  blr
