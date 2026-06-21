# crt0.S -- startup for the single-cycle RV32I core.
# Sets the stack pointer, zeroes .bss, calls main(), then writes the HALT
# MMIO register (0x1000000C) so the simulation testbench can $finish.
# Reset PC is 0x0, so _start must be the very first instruction (.text.init).
    .section .text.init
    .globl _start
_start:
    la   sp, _stack_top         # stack at top of 64 KiB data RAM

    la   t0, __bss_start        # zero the .bss section
    la   t1, __bss_end
1:  bge  t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b

2:  li   a0, 0                  # argc = 0
    li   a1, 0                  # argv = NULL
    call main

    li   t0, 0x1000000C         # HALT register
    sw   a0, 0(t0)              # store main()'s return value -> assert halt
3:  j    3b                     # spin forever (board) / never reached (sim finishes)
