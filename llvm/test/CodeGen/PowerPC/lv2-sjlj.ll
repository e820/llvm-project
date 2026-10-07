; CellOS LV2 has 32-bit pointers on 64-bit PowerPC. The __builtin_setjmp
; buffer is five pointer-sized (4-byte) slots: Clang stores the frame address
; in slot 0 and the stack pointer in slot 2; the backend owns the jump address
; (slot 1), the TOC pointer (slot 3) and the base pointer (slot 4).
; RUN: llc -verify-machineinstrs -mtriple=powerpc64-unknown-lv2 < %s | FileCheck %s

@jmpbuf = global [5 x ptr] zeroinitializer

define i32 @sjlj_setjmp() {
; CHECK-LABEL: sjlj_setjmp:
; CHECK:       ld [[BUF:[0-9]+]], .LC{{[0-9]+}}@toc@l(
; CHECK-DAG:   stw 2, 12([[BUF]])
; CHECK-DAG:   stw 1, 16([[BUF]])
; CHECK:       bcl 20, 31, [[MAIN:\.LBB[0-9_]+]]
; CHECK:       [[MAIN]]:
; CHECK:       mflr [[LR:[0-9]+]]
; CHECK-NEXT:  stw [[LR]], 4({{[0-9]+}})
  %fa = call ptr @llvm.frameaddress(i32 0)
  store ptr %fa, ptr @jmpbuf
  %ss = call ptr @llvm.stacksave()
  store ptr %ss, ptr getelementptr (ptr, ptr @jmpbuf, i32 2)
  %r = call i32 @llvm.eh.sjlj.setjmp(ptr @jmpbuf)
  ret i32 %r
}

define void @sjlj_longjmp() {
; CHECK-LABEL: sjlj_longjmp:
; CHECK:       ld [[BUF:[0-9]+]], .LC{{[0-9]+}}@toc@l(
; CHECK-DAG:   lwz 31, 0([[BUF]])
; CHECK-DAG:   lwz [[IP:[0-9]+]], 4([[BUF]])
; CHECK-DAG:   lwz 1, 8([[BUF]])
; CHECK-DAG:   lwz 2, 12([[BUF]])
; CHECK-DAG:   lwz 30, 16([[BUF]])
; CHECK-DAG:   mtctr [[IP]]
; CHECK:       bctr
  call void @llvm.eh.sjlj.longjmp(ptr @jmpbuf)
  unreachable
}
