; CellOS LV2 function descriptors are 8 bytes, {u32 entry, u32 TOC base}, with
; no environment pointer. Function code is entered through a dot-symbol
; (".foo") that direct calls branch to, while "foo" names the descriptor.
; RUN: llc -verify-machineinstrs -mtriple=powerpc64-unknown-lv2 < %s | FileCheck %s
; RUN: llc -verify-machineinstrs -mtriple=powerpc64-unknown-lv2 -filetype=obj < %s | \
; RUN:   llvm-readobj -h -r - | FileCheck %s --check-prefix=OBJ
; RUN: llc -verify-machineinstrs -mtriple=powerpc64-unknown-lv2 -filetype=obj < %s | \
; RUN:   llvm-readobj --section-groups - | FileCheck %s --check-prefix=GROUP

; OBJ:      OS/ABI: 0x66
; OBJ:      Flags [ (0x0)
; OBJ:      Section ({{[0-9]+}}) .rela.opd {
; OBJ-NEXT:   0x0 R_PPC64_ADDR32 .text 0x0
; OBJ-NEXT:   0x4 R_PPC64_ADDR32 .TOC. 0x0
; OBJ-NEXT:   0x8 R_PPC64_ADDR32 .text 0x{{[0-9A-F]+}}
; OBJ-NEXT:   0xC R_PPC64_ADDR32 .TOC. 0x0

declare i32 @callee(i32)

; CHECK:      .type local_fn,@function
; CHECK-NEXT: .section .opd,"aw",@progbits
; CHECK-NEXT: .p2align 3
; CHECK-NEXT: local_fn:
; CHECK-NEXT: .long [[LOCAL_BEGIN:\.Lfunc_begin[0-9]+]]
; CHECK-NEXT: .long .TOC.
; CHECK-NEXT: .text
; CHECK-NOT:  .globl .local_fn
; CHECK-NEXT: .type .local_fn,@function
; CHECK-NEXT: .local_fn:
; CHECK-NEXT: [[LOCAL_BEGIN]]:
; CHECK:      .size .local_fn, .Lfunc_end{{[0-9]+}}-[[LOCAL_BEGIN]]
define internal i32 @local_fn(i32 %x) noinline {
  %r = add i32 %x, 1
  ret i32 %r
}

; CHECK:      .globl caller
; CHECK:      caller:
; CHECK-NEXT: .long .Lfunc_begin{{[0-9]+}}
; CHECK-NEXT: .long .TOC.
; CHECK-NEXT: .text
; CHECK-NEXT: .globl .caller
; CHECK-NEXT: .type .caller,@function
; CHECK-NEXT: .caller:
; CHECK:      bl .callee
; CHECK-NEXT: nop
; CHECK:      bl .local_fn
; CHECK-NOT:  nop
; CHECK:      bl .memcpy
; CHECK-NEXT: nop
define i32 @caller(ptr %d, ptr %s, i32 %n) {
  %a = call i32 @callee(i32 %n)
  %b = call i32 @local_fn(i32 %a)
  call void @llvm.memcpy.p0.p0.i32(ptr %d, ptr %s, i32 %b, i1 false)
  ret i32 %b
}

; The descriptor's entry and TOC words are loaded with lwz, and no environment
; pointer is loaded into r11.
; CHECK-LABEL: .indirect:
; CHECK-DAG:   std 2, 40(1)
; CHECK-DAG:   lwz [[ENTRY:[0-9]+]], 0([[DESC:[0-9]+]])
; CHECK-DAG:   lwz 2, 4([[DESC]])
; CHECK-DAG:   mtctr [[ENTRY]]
; CHECK-NOT:   {{(ld|lwz) 11,}}
; CHECK:       bctrl
; CHECK-NEXT:  ld 2, 40(1)
define i32 @indirect(ptr %f) {
  %r = call i32 %f(i32 7)
  ret i32 %r
}

; CHECK-LABEL: .tail:
; CHECK:       b .local_fn
define i32 @tail(i32 %x) {
  %r = tail call i32 @local_fn(i32 %x)
  ret i32 %r
}

; CHECK:      .weak .weakfn
; CHECK-NEXT: .hidden .weakfn
; CHECK-NEXT: .type .weakfn,@function
; CHECK-NEXT: .weakfn:
define weak hidden void @weakfn() {
  ret void
}

; A COMDAT function's descriptor goes into an .opd section in the function's
; group, so linkers discard duplicate descriptors with the duplicate code.
; CHECK:      .section .text.inline_fn,"axG",@progbits,inline_fn,comdat
; CHECK:      .section .opd,"awG",@progbits,inline_fn,comdat
; CHECK-NEXT: .p2align 3
; CHECK-NEXT: inline_fn:
; CHECK-NEXT: .long .Lfunc_begin{{[0-9]+}}
; CHECK-NEXT: .long .TOC.
; CHECK-NEXT: .section .text.inline_fn,"axG",@progbits,inline_fn,comdat
; CHECK-NEXT: .weak .inline_fn
; CHECK-NEXT: .hidden .inline_fn

; GROUP:      Signature: inline_fn
; GROUP-NEXT: Section(s) in group [
; GROUP-NEXT:   .text.inline_fn
; GROUP-NEXT:   .opd
; GROUP-NEXT:   .rela.opd
; GROUP-NEXT: ]
$inline_fn = comdat any
define linkonce_odr hidden i32 @inline_fn(i32 %x) comdat {
  %r = mul i32 %x, 3
  ret i32 %r
}

; Calls through an alias branch to the alias's entry symbol.
; CHECK-LABEL: .via_alias:
; CHECK:       bl .pub_alias
define i32 @via_alias(i32 %x) {
  %r = call i32 @pub_alias(i32 %x)
  ret i32 %r
}

; CHECK:      .globl pub_alias
; CHECK:      pub_alias = local_fn
; CHECK-NEXT: .globl .pub_alias
; CHECK-NEXT: .type .pub_alias,@function
; CHECK-NEXT: .pub_alias = .local_fn
@pub_alias = alias i32 (i32), ptr @local_fn
