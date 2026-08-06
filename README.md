# riscv-core

A RISC-V RV32I processor written from scratch in SystemVerilog. I write mostly software,
and I wanted to actually understand the machine underneath it: what a fetch-decode-execute
cycle costs in real hardware, not just what the ISA manual says it does. This is that
project. It runs the official `riscv-tests` suite, and it runs on real silicon, not just in
simulation.

## What it does

The core implements the full RV32I base integer ISA: all R, I, S, B, U and J-type
instructions, byte and halfword load/store with sign and zero extension, `jal`/`jalr`,
`lui`/`auipc`, and all six branch conditions.

It is currently single-cycle. One instruction retires every clock: fetch through writeback
happens combinationally within the cycle, and only the PC, register file, and data memory
are clocked.

A 5-stage pipeline (IF/ID/EX/MEM/WB, with hazard detection and forwarding) is in progress
and not yet in this repo.

See [`docs/architecture.md`](docs/architecture.md) for the datapath, the memory-mapped I/O
layout (UART, cycle counter, halt register), and the Harvard memory model used in both
simulation and on the board.

## Verification

Every module in `rtl/` has its own self-checking testbench in `tb/`. Each one prints
`... : ALL TESTS PASSED` on success, so there's no waveform-reading required to know a run
went well.

The core is also run against the official `riscv-tests` `rv32ui` suite. Current result: 40
of 41 pass. The one failure is `ma_data`, which exercises misaligned data accesses: the core
doesn't implement misalignment traps yet, so it fails that test honestly rather than
silently doing the wrong thing. `fence_i` is skipped by the test runner because it needs
self-modifying code, and a Harvard-memory core (separate instruction and data memories)
can't do that.

## Results

CoreMark: 17 iterations/s at 12.5 MHz, which works out to 1.36 CoreMark/MHz on the
single-cycle core. The run is CRC-verified (CoreMark checks its own output against a
known-good checksum), built with GCC 13.2 at `-O2 -march=rv32i`, 300 iterations.

It runs on a Digilent Nexys 4 (Xilinx Artix-7, `xc7a100tcsg324-1`), with output reported
back to a host terminal over UART.

## Layout
```
rtl/          synthesizable modules: the CPU datapath and the MMIO peripherals
tb/           self-checking testbenches, one per rtl/ module plus integration tests
programs/     hex memory images ($readmemh format)
tests/        riscv-tests harness (build.sh compiles the suite, run.sh runs it)
bench/        CoreMark port (EEMBC sources, plus the bare-metal glue in bench/port/)
constraints/  Nexys 4 pin constraints (.xdc)
docs/         architecture reference
riscv-tests/  the official ISA test suite (git submodule)
build_board.tcl   Vivado project for the board bring-up actually used for the CoreMark run
Makefile      simulation harness (make sim / make wave / make clean)
```

## Prerequisites
```bash
sudo apt install -y iverilog gtkwave
```
Building any C program (CoreMark, hello world) or the riscv-tests suite needs a RISC-V GCC
toolchain (`riscv64-unknown-elf-gcc`; this was built and tested against GCC 13.2). Building
for the board needs Xilinx Vivado.

`riscv-tests` is a git submodule, so after cloning:
```bash
git submodule update --init
```

## Running a simulation
```bash
make sim  TB=cpu_top      # compile rtl/ plus one testbench, then run it
make wave TB=cpu_top      # open that run's waveform in GTKWave
make clean
```
`TB` picks which testbench in `tb/` to run; it defaults to `register_file`. `cpu_top` is the
full-RV32I regression, exercising every instruction class in one program.

## Running the riscv-tests suite
```bash
bash tests/build.sh       # compile the rv32ui tests to hex images (needs the toolchain)
bash tests/run.sh         # load each into the core, check the tohost result
```

## Building and simulating CoreMark
```bash
bench/cc.sh -o coremark bench/coremark/core_*.c bench/coremark/ee_printf.c \
  bench/port/core_portme.c -Ibench/coremark -DITERATIONS=300 -DPERFORMANCE_RUN=1 \
  '-DFLAGS_STR="-O2"'
```
That builds `programs/coremark.hex`. To run it in simulation:
```bash
iverilog -g2012 -o build/cm.vvp \
  $(ls rtl/*.sv | grep -vE 'nexys4_top|board_top|clock_divider') tb/coremark_tb.sv
vvp build/cm.vvp
```
It's a long run: CoreMark on a single-cycle core with software multiply/divide takes
millions of cycles even for a handful of iterations. It prints CoreMark's own report,
including its CRC self-check line, over the simulated UART.

## Building for the board
```bash
bench/cc.sh -o prog bench/hello/hello.c      # or your own program, built the same way
vivado -mode batch -source build_board.tcl
```
Then, inside Vivado: `launch_runs impl_1 -to_step write_bitstream`, then
`wait_on_run impl_1`, then use the Hardware Manager to program the `.bit` file. On the host:
```bash
picocom -b 115200 /dev/ttyUSB1      # or: screen /dev/ttyUSB1 115200
```
`build_board.tcl` targets `board_top`, the module that actually ran the CoreMark benchmark
on hardware. There's an older `nexys4_top` module and a `build.tcl` from an earlier
bring-up attempt, before the UART and MMIO peripherals existed. I moved on to `board_top`
before finishing it, so it's currently broken (it references a `debounce` module I never
wrote).

## Status

Done:
- Full RV32I base ISA, single-cycle
- `riscv-tests` `rv32ui` suite, 40 of 41 (see Verification above for the one failure)
- Synthesized and running on the Nexys 4, UART output to a host terminal
- CoreMark on hardware, CRC-verified

In progress:
- 5-stage pipeline, with hazard detection and forwarding

Not there yet:
- Misaligned-access traps, the reason `ma_data` fails
- Any privileged ISA or CSRs: no `rdcycle`, no interrupts, no traps. Timing comes from a
  memory-mapped cycle counter instead
- Synthesis timing (Fmax) and resource utilization. I haven't captured and reported real
  numbers from Vivado yet, so none are quoted here

## License

The core's source is released under the [MIT License](LICENSE).

The CoreMark sources under `bench/coremark/` are (c) EEMBC, distributed under the Apache
License 2.0. See the [official CoreMark repository](https://github.com/eembc/coremark) for
the license and the score-reporting rules.
