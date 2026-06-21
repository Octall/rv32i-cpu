// =============================================================================
// riscv_test.h  --  minimal test environment for the single-cycle RV32I core
// =============================================================================
// The official riscv-tests "-p" environment reports pass/fail through ECALL +
// a machine-mode trap handler (needs CSRs). This core is pure RV32I, so we use
// a tiny environment instead: report by writing a code to the `tohost` memory
// word, then spin.
//     tohost == 1            -> PASS
//     tohost == (N<<1)|1     -> FAIL at sub-test N   (so N = tohost>>1)
// This runs the REAL rv32ui test bodies with no privileged support.
// =============================================================================
#ifndef _ENV_RVCORE_H
#define _ENV_RVCORE_H

#define RVTEST_RV32U
#define RVTEST_RV32M
#define RVTEST_RV32S
#define RVTEST_RV64U
#define TESTNUM gp

#define RVTEST_CODE_BEGIN   \
        .section .text.init;\
        .align 2;           \
        .globl _start;      \
_start:

#define RVTEST_CODE_END

#define RVTEST_PASS         \
        li   t0, 1;         \
        la   t1, tohost;    \
        sw   t0, 0(t1);     \
1:      j    1b;

#define RVTEST_FAIL             \
        slli TESTNUM, TESTNUM, 1; \
        ori  TESTNUM, TESTNUM, 1; \
        la   t1, tohost;        \
        sw   TESTNUM, 0(t1);    \
1:      j    1b;

#define RVTEST_DATA_BEGIN  .section .data; .align 4;
#define RVTEST_DATA_END    .align 4; .global tohost; tohost: .word 0;

#endif
