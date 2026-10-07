/// The CellOS Lv-2 PPU ABI makes plain char signed, unlike other PowerPC ELF
/// targets.
// RUN: %clang -### %s --target=powerpc64-unknown-lv2 -c 2>&1 | FileCheck %s
// RUN: %clang -### %s --target=powerpc64-unknown-lv2 -funsigned-char -c 2>&1 \
// RUN:   | FileCheck %s --check-prefix=UNSIGNED
// RUN: %clang -### %s --target=powerpc64-unknown-linux-gnu -c 2>&1 \
// RUN:   | FileCheck %s --check-prefix=UNSIGNED

// CHECK: "-cc1" "-triple" "powerpc64-unknown-lv2"
// CHECK-NOT: "-fno-signed-char"

// UNSIGNED: "-cc1"
// UNSIGNED-SAME: "-fno-signed-char"
