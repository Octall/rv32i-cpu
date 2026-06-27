# riscv-core — Architecture

A from-scratch **single-cycle RV32I** soft processor in SystemVerilog, wrapped in a small
SoC (CPU + Harvard memories + memory-mapped peripherals) targeting a Digilent **Nexys 4**
(Xilinx Artix-7 XC7A100T). Simulated with Icarus Verilog; synthesized with Vivado.

> Snapshot: reflects the design after the SoC bus + peripherals were added (Phase 0/1 of the
> CoreMark effort — see `coremark-benchmark-plan.md`). Verified: `rv32ui` 40/41 pass
> (`ma_data` expected-fail, needs misalignment traps), all unit testbenches, and the
> end-to-end `soc_smoke` test.

---

## 1. Top-level structure

```
                          coremark_top / nexys4_top   (board wrappers, synthesis top)
                                      │
                                      ▼
   ┌───────────────────────────────────────────────────────────────────────┐
   │  cpu_top  (the SoC: datapath + bus + peripherals)                       │
   │                                                                         │
   │   PC ─▶ instr_memory ─▶ decode ─▶ regfile/imm ─▶ ALU ─▶ data bus ─▶ WB  │
   │                                                    │                    │
   │                                          addr[28]? │ (bus decode)       │
   │                              ┌──────────────────────┴──────────┐        │
   │                              ▼                                  ▼        │
   │                      data_memory (RAM)              MMIO peripherals     │
   │                      0x0000_0000+                   0x1000_0000+         │
   │                                                  uart_tx · cycle_counter │
   │                                                  · HALT                  │
   └───────────────────────────────────────────────────────────────────────┘
```

- **`cpu_top`** is the integration unit: it contains the CPU datapath, both memories, the
  MMIO address decode, and the peripherals. New top-level outputs: `uart_tx` (serial line)
  and `halt` (stop signal).
- **Board wrappers** (`nexys4_top`, future `coremark_top`) instantiate `cpu_top`, supply the
  clock/reset, and route `uart_tx` / LEDs / 7-seg to physical pins. The wrapper — not
  `cpu_top` — is the Vivado synthesis top.

---

## 2. CPU datapath (single-cycle RV32I)

One instruction completes every clock — fetch, decode, execute, memory, and writeback all
happen combinationally within a cycle; only the PC, register file, and data memory are
clocked. Effective CPI = 1.

**Per-cycle flow** (`cpu_top.sv`):

1. **Fetch** — `program_counter` holds `pc`; `instr_memory` returns `instr` combinationally.
2. **Decode** — instruction fields sliced directly; `control_unit` maps opcode/funct3/funct7[5]
   to control signals; `imm_gen` reconstructs the immediate per format.
3. **Register read** — `register_file` returns `rs1_data`/`rs2_data` (combinational reads).
4. **Execute** — operand muxes feed the `alu`:
   - ALU-A: `rs1` / `pc` (auipc) / `0` (lui), selected by `alu_a_src`.
   - ALU-B: `rs2` / `imm`, selected by `alu_b_src`.
   - `branch_unit` independently computes branch-taken from funct3.
5. **Memory** — `alu_result` is the load/store address into the **data bus** (§4).
   `store_align` builds the write data + byte-enables; `load_extend` selects/sign-extends
   the loaded word per funct3.
6. **Writeback** — `result_src` mux picks ALU result / load data / `pc+4` (link) → register
   file write.
7. **Next PC** — `pc+4`, or `pc+imm` (branch/jal), or `(rs1+imm)&~1` (jalr).

---

## 3. Module inventory (`rtl/`)

| Module | Kind | Responsibility |
|---|---|---|
| `cpu_top` | structural | Datapath wiring + SoC bus + peripherals; top of the core |
| `program_counter` | seq | PC register; `pc+4` or loaded jump/branch target |
| `instr_memory` | comb read | Instruction ROM, 16384×32 (`$readmemh` init), index `addr[15:2]` |
| `control_unit` | comb | Opcode/funct → control signals (the decode table) |
| `imm_gen` | comb | Reconstruct I/S/B/U/J immediates |
| `register_file` | seq write / comb read | 32×32 GPRs; 2 read ports, 1 write port |
| `alu` | comb | add/sub/logic/shift/compare; 4-bit `alu_op` |
| `branch_unit` | comb | Branch-taken decision from funct3 (beq/bne/blt/bge/bltu/bgeu) |
| `store_align` | comb | Per-funct3 store data alignment + 4-bit byte-enables |
| `data_memory` | seq write / comb read | RAM, 16384×32, per-byte write enables, optional `INIT_FILE` |
| `load_extend` | comb | Byte/half/word select + sign/zero extension of loaded word |
| `cycle_counter` | seq | Free-running 32-bit cycle counter (the MMIO time source) |
| `uart_tx` | seq | 115200-8N1 serial transmitter (memory-mapped) |
| `clock_divider` | seq | Slow clock generator (used by the `nexys4_top` demo only) |
| `sev_seg` | comb | 7-segment display driver (available; not yet wired) |
| `nexys4_top` | structural | Original board demo (runs CPU slow, shows PC/reg on LEDs) |

Each `rtl/` module has a matching self-checking testbench in `tb/`.

---

## 4. Memory architecture & the data bus

### Harvard, unified-image
Instruction and data live in **separate** memories (`instr_memory`, `data_memory`), each
**16384 words = 64 KiB**, indexed by `addr[15:2]`. Programs are linked as **one image at
`0x0`** and the **same hex is loaded into both memories** — instruction fetch hits the imem
copy, loads/stores hit the dmem copy. `.bss` and the stack live above the loaded image in
dmem; the stack starts at `_stack_top = 0x0000FFF0` and grows down.

`data_memory` supports byte/half/word writes via 4 per-lane byte-enables (from `store_align`)
and returns a full 32-bit word on read (`load_extend` does the sub-word select/extend).

### Bus decode (added in `cpu_top`)
A single address bit splits the load/store space:

```
is_mmio = alu_result[28];          // 0x1000_0000+  → peripherals, else → RAM
dmem_we = mem_write & ~is_mmio;    // RAM writes suppressed for MMIO addresses
mem_rdata = is_mmio ? mmio_rdata : dmem_rdata;   // load path mux
```

Because RAM occupies `0x0000_0000–0x0000_FFFF` (bit 28 always 0), the decode is transparent
to ordinary programs and to the `rv32ui` test suite.

---

## 5. Memory map (MMIO)

| Address | Access | Register | Behavior |
|---|---|---|---|
| `0x0000_0000…0x0000_FFFF` | R/W | RAM | 64 KiB data memory (image also in imem) |
| `0x1000_0000` | W | `UART_TX_DATA` | Store a byte → transmit it (one-cycle `start` pulse) |
| `0x1000_0004` | R | `UART_STATUS` | bit0 = `tx_busy` (1 = busy; poll before writing) |
| `0x1000_0008` | R | `CYCLE_COUNTER` | Free-running 32-bit cycle count (time source) |
| `0x1000_000C` | W | `HALT` | Any store asserts `cpu_top.halt` (sim `$finish`) |

MMIO register select uses `alu_result[3:2]`; reads are combinational (single-cycle loads).
A store to `UART_TX_DATA` naturally produces a one-cycle `start` pulse because `mem_write`
is high for exactly one cycle per store on a single-cycle core.

---

## 6. Peripherals

- **`uart_tx`** — `#(CLK_HZ=100_000_000, BAUD=115_200)`; ports `(clk, rst_n, start, data[7:0],
  tx, busy)`. 8N1, LSB-first, idle-high; a 10-bit `{stop, data, start}` shift register
  emits one bit every `CLK_HZ/BAUD` (868) cycles. `busy` gates new sends; software polls
  `UART_STATUS` before each byte.
- **`cycle_counter`** — `(clk, rst_n, count[31:0])`; resets to 0, `+1` every cycle. Read via
  `CYCLE_COUNTER`; this is how software measures elapsed time (the core has **no CSRs**, so
  no `rdcycle`/`mcycle`).
- **`HALT`** — not a module; a decoded store that drives the `halt` output so a testbench can
  end the run and a board wrapper can stop/indicate completion.

---

## 7. ISA support & known limitations

- **RV32I base integer ISA**, single-cycle, full base set (R/I/load/store/branch/lui/auipc/
  jal/jalr; `fence` = NOP).
- **No `M` extension** — multiply/divide are provided by libgcc software routines
  (`__mulsi3`, `__divsi3`, …) at compile time.
- **No CSRs / privileged mode** — no traps, no `rdcycle`; timing comes from the MMIO
  `cycle_counter` peripheral instead.
- **No misaligned-access trapping** — `ma_data` is the one expected `rv32ui` failure.
- **Not pipelined** — single-cycle (the README lists a 5-stage pipeline as a stretch goal).

---

## 8. Software toolchain (`bench/`)

Bare-metal C/asm → `$readmemh` image, built with `riscv64-unknown-elf-gcc` (`-march=rv32i
-mabi=ilp32`):

- **`bench/cc.sh`** — `cc.sh -o NAME a.c [b.c …] [flags]`. Compiles + links bare-metal (crt0
  first so `_start` is at reset PC `0x0`), pulls in `-lgcc`, then `objcopy → bin →
  bin2hex.py → programs/NAME.hex`. Reports word count + entry and **fails** if the image
  exceeds 16384 words or doesn't start at `0x0`.
- **`bench/port/link.ld`** — unified image at `0x0`; every section is `ALIGN(4)`, `.bss` is
  word-aligned (`__bss_start`/`__bss_end` on word boundaries), stack at `0x0000FFF0`.
  *(The alignment is load-bearing: crt0 zeroes `.bss` with word stores, so an unaligned
  `.bss` sharing a word with `.rodata` would corrupt it.)*
- **`bench/port/crt0.S`** — sets `sp`, zeroes `.bss`, calls `main`, stores `main`'s return
  value to the `HALT` register, then spins.
- **`bench/port/mmio.h`** — `uart_putc`/`uart_puts`/`cycles()` over the `0x1000_0000` map.
- **`bench/hello/hello.c`** — bring-up program; prints `"Hello from RV32I\n"` and exercises
  `.rodata`/`.data`/`.bss`.

---

## 9. Verification (`tb/`)

- **Unit testbenches** — one self-checking `*_tb.sv` per `rtl/` module (the module's spec);
  print `ALL TESTS PASSED`.
- **`test_runner.sv`** — runs the official **`riscv-tests` rv32ui** suite: loads each test
  image into both memories, runs, watches the `tohost` word for pass/fail. Current: **40/41
  pass** (`ma_data` expected-fail). Driven by `tests/run.sh` (build via `tests/build.sh`).
- **`soc_smoke_tb.sv`** — end-to-end SoC test: loads `hello.hex`, decodes the `uart_tx`
  serial line with an independent oversampling receiver, checks the bytes equal
  `"Hello from RV32I\n"`, and stops on `halt`. Exercises CPU + bus + UART + status polling +
  software sections + halt together.

---

## 10. Board integration

- **`nexys4_top`** — original demo wrapper: divides the 100 MHz clock down so the CPU is
  watchable, shows the PC or a watched register on the 16 LEDs. Does not use the UART.
- **`coremark_top`** (planned, Phase 4) — full-speed wrapper: runs `cpu_top` directly on
  `CLK100MHZ`, routes `uart_tx` to the Nexys 4 USB-UART `UART_RXD_OUT` pin (D4) for output
  on a host serial terminal, and reports Fmax / utilization from Vivado.

Pin constraints live in `constraints/` (`nexys4.xdc` + the Digilent master XDC); the build
script is `build.tcl`.
```
