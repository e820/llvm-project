; CellOS LV2 function descriptors have no environment pointer, so nested
; function trampolines cannot be built.
; RUN: not llc -mtriple=powerpc64-unknown-lv2 < %s 2>&1 | FileCheck %s

; CHECK: LLVM ERROR: trampolines are not supported by the CellOS LV2 ABI

define void @nested(ptr nest %n) {
  ret void
}

define void @tramp(ptr %t, ptr %n) {
  call void @llvm.init.trampoline(ptr %t, ptr @nested, ptr %n)
  ret void
}
