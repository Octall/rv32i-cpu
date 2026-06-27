# riscv-core

A RISC-V **RV32I** soft processor written from scratch in **SystemVerilog** — simulated
with Icarus Verilog, validated against the official `riscv-tests` ISA suite, and **running
on real silicon** (Digilent Nexys 4, Xilinx Artix-7).

## Highlights

- ✅ **Full RV32I base ISA** — all R/I/S/B/U/J-type instructions, byte-addressed
  load/store, `jal`/`jalr`, `lui`/`auipc`, and every branch condition.
- ✅ **Validated** against the official **`riscv-tests`** `rv32ui` suite.
- ✅ **Running on hardware** (Artix-7, `xc7a100tcsg324-1`) with UART output to host.
- ✅ **CoreMark: 17 iter/s @ 12.5 MHz → 1.36 CoreMark/MHz** (single-cycle), CRC-verified.
- 🚧 **5-stage pipeline** (IF/ID/EX/MEM/WB with hazard detection + forwarding) — in progress.

Every module ships with its own self-checking testbench in `tb/`.

## Layout
```
rtl/          synthesizable modules (the CPU + MMIO peripherals)
tb/           self-checking testbenches (the specs)
programs/     hex test programs
tests/        riscv-tests harness (build.sh / run.sh)
bench/        CoreMark port (EEMBC; see attribution below)
constraints/  Nexys 4 .xdc pin constraints
build_board.tcl   Vivado project for board bring-up
Makefile      one-command simulation harness
```

## Prerequisites
```bash
sudo apt update && sudo apt install -y iverilog gtkwave
```
Hardware/benchmark phases also need Xilinx **Vivado** (Nexys 4 synthesis) and the
`gcc-riscv64-unknown-elf` toolchain (use `-march=rv32i_zicsr_zifencei`).

## Running a simulation
```bash
make sim  TB=cpu_top      # compile all rtl + one testbench, then run it
make wave TB=cpu_top      # open that run's waveform in GTKWave
make clean
```
`TB` selects which testbench in `tb/` to run. A passing run prints `... : ALL TESTS PASSED`.

## Running the riscv-tests suite
```bash
bash tests/build.sh       # compile the rv32ui tests to hex images
bash tests/run.sh         # load each into the core and check the tohost result
```

## Architecture

See [`docs/architecture.md`](docs/architecture.md) for the datapath, the memory-mapped I/O
layout (UART, cycle counter, halt register), and the Harvard memory model used for
simulation and on-board execution.

## Roadmap
- [x] Complete RV32I base ISA, single-cycle
- [x] Pass the official `riscv-tests` `rv32ui` suite
- [x] Synthesize and run on the Nexys 4 (Artix-7), UART to host
- [x] CoreMark benchmark on hardware
- [ ] 5-stage pipeline with hazard detection + forwarding
- [ ] Reimplement a module in **Hardcaml** (OCaml) as a high-level-HDL exercise

## License

This project's source is released under the [MIT License](LICENSE).

The CoreMark sources under `bench/coremark/` are © EEMBC, distributed under the
Apache License 2.0 — see the [official CoreMark repository](https://github.com/eembc/coremark)
for the full license and score-reporting rules.
