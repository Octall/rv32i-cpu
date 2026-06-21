# riscv-core

A RISC-V **RV32I** soft core written from scratch in **SystemVerilog**, simulated with
Icarus Verilog and targeted at a Digilent **Nexys 4** (Xilinx Artix-7) board.

> Built as a learning project: single-cycle first, then refactored to a 5-stage pipeline.
> Every module ships with a self-checking testbench.

## Layout
```
rtl/        synthesizable modules (the CPU)
tb/         self-checking testbenches (the specs)
programs/   hex test programs (added later)
Makefile    one-command simulation harness
```

## Prerequisites
```bash
sudo apt update && sudo apt install -y iverilog gtkwave
```
Later phases also need Xilinx **Vivado** (Nexys 4 synthesis) and the
`gcc-riscv64-unknown-elf` toolchain (compiling C/asm test programs).

## Running a simulation
```bash
make sim  TB=register_file      # compile all rtl + one testbench, then run it
make wave TB=register_file      # open that run's waveform in GTKWave
make clean
```
`TB` selects which testbench in `tb/` to run (defaults to `register_file`). A passing run
prints `... : ALL TESTS PASSED`.

## The development loop
1. Read the module's testbench in `tb/` — it's the contract.
2. Write the module in `rtl/`.
3. `make sim TB=<module>` until it passes.
4. `make wave TB=<module>` to debug from the waveform when a check fails.

## Roadmap — RV32I single-cycle
Build in order; each gets a module **and** a testbench (copy the `register_file` pattern).

- [x] `register_file` — 32×32-bit register state *(worked example)*
- [x] `program_counter` — the PC register
- [x] `instr_memory` — instruction ROM (`$readmemh`)
- [x] `imm_gen` — reconstruct I/S/B/U/J immediates
- [x] `alu` — add/sub/logic/shift/compare ops
- [x] `control_unit` — decode opcode/funct → control signals
- [x] `data_memory` — load/store RAM
- [x] `cpu_top` — wire the datapath together and run real programs ✅ **working core**

## Stretch goals
- Pass the official `riscv-tests` ISA suite.
- **Hardware:** Vivado + Nexys 4 constraints; prove it runs on the board; report Fmax and
  LUT/FF/BRAM utilization.
- **Pipeline:** refactor to 5-stage (IF/ID/EX/MEM/WB) with hazard detection + forwarding.
- Reimplement a module in **Hardcaml** (OCaml) as a high-level-HDL exercise.
