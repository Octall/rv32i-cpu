# CoreMark on the RV32I core — Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking. This is a
> collaborative, DIY plan: **you write the RTL modules** (`uart_tx`, `cycle_counter`)
> against the contracts + self-checking testbenches given here — exactly the repo's
> existing "read the testbench, then write the module" loop. I provide the glue
> (bus decode, linker, crt0, the CoreMark port, build scripts, sim testbench, board
> top, Vivado flow) and review your modules.

**Goal:** Run CoreMark on the single-cycle RV32I core, get a CRC-validated CoreMark/MHz
number in simulation, then run it on the Nexys 4 and report CoreMark, Fmax, and LUT/FF/BRAM
utilization.

**Architecture:** Add a one-bit MMIO decode to `cpu_top` (`addr[31]` ⇒ peripherals, else
data RAM). Two new peripherals: a free-running `cycle_counter` (the time source CoreMark
needs) and a memory-mapped `uart_tx` (CoreMark's text output), plus a `halt` register so
simulation can stop. CoreMark is built bare-metal (its `barebones` port) into **one image
linked at `0x0`, loaded into both Harvard memories**; `.bss`/stack live above it in dmem.

**Tech Stack:** SystemVerilog (Icarus for sim, Vivado for the board), `riscv64-unknown-elf-gcc`
(`-march=rv32i -mabi=ilp32`), CoreMark (EEMBC), Nexys 4 (Artix-7 XC7A100T), 115200-8N1 UART
over the board's USB-UART bridge.

---

## Progress

- ✅ **Phase 0** — memories grown to 16K words, `data_memory` `INIT_FILE`, `addr[28]` MMIO
  decode in `cpu_top`. Regression held at 40/1 (`ma_data`).
- ✅ **Phase 1** — `cycle_counter` + `uart_tx` written (by Mahmoud) and passing; wired into
  `cpu_top`; **SoC smoke test green** (`"Hello from RV32I\n"` end-to-end).
- 🛠 **Linker bug fixed** — `.bss` was unaligned (`0x86`), sharing a word with `.rodata`;
  `crt0`'s word-store zeroing clobbered it. All sections now `ALIGN(4)`; `__bss_start=0x88`.
- ⬜ **Phase 2 remainder** — vendor CoreMark + `core_portme.c/.h`, build via `cc.sh`.
- ⬜ **Phase 3/4** — sim CoreMark run → board.

## Memory map (the contract everything shares)

| Address        | R/W | Meaning                                                        |
|----------------|-----|---------------------------------------------------------------|
| `0x0000_0000`… | R/W | RAM (data memory). Same image is also in instruction memory.  |
| `0x1000_0000`  | W   | `UART_TX_DATA` — store a byte ⇒ transmit it (1-cycle `tx_start`) |
| `0x1000_0004`  | R   | `UART_STATUS` — bit0 = `tx_busy` (1 = transmitting, wait)      |
| `0x1000_0008`  | R   | `CYCLE_COUNTER` — free-running 32-bit cycle count              |
| `0x1000_000C`  | W   | `HALT` — store any value ⇒ assert `cpu_top.halt` (sim `$finish`) |

Decode rule: `is_mmio = addr[28]`. Within MMIO, select the register with `addr[3:2]`.
RAM index stays `addr[15:2]` (16384 words = 64 KiB). Nothing the rv32ui tests touch lands
at `0x1000_0000`, so the decode is transparent to them — that's regression gate #1.
(Addresses match `docs/uart-implementation-guide.md`.)

---

## File structure

**RTL (modify):**
- `rtl/instr_memory.sv` — `DEPTH` 4096 → 16384.
- `rtl/data_memory.sv` — `DEPTH` 4096 → 16384; add `INIT_FILE` + `$readmemh`.
- `rtl/cpu_top.sv` — MMIO decode; gate dmem writes; mux read data; instantiate peripherals;
  new ports `uart_tx`, `halt`.

**RTL (create — you write these):**
- `rtl/cycle_counter.sv`
- `rtl/uart_tx.sv`  *(detailed how-to: your `write-a-guide` fork output)*

**Testbenches (create — I provide):**
- `tb/cycle_counter_tb.sv`, `tb/uart_tx_tb.sv`, `tb/soc_smoke_tb.sv`, `tb/coremark_tb.sv`

**Software (✅ already created by the compile-script fork — on disk now):**
- `bench/cc.sh` — general C/asm → `programs/NAME.hex` compiler (`-march=rv32i`, `-lgcc`,
  unified image at `0x0`, size guard at 16384 words). Replaces the planned `build.sh`.
- `bench/port/crt0.S`, `bench/port/link.ld`, `bench/port/mmio.h` — startup, unified-image
  linker, MMIO handles (all matching the `0x1000_0000` map).
- `bench/hello/hello.c` + `programs/hello.hex` — UART bring-up program (already built).

**Software (still to create):**
- `bench/coremark/` — vendored CoreMark sources (barebones port).
- `bench/port/core_portme.c`, `bench/port/core_portme.h` — timing + UART glue.

**Board (create/modify):**
- `rtl/coremark_top.sv` — full-speed board wrapper (no slow clock divider).
- `constraints/nexys4.xdc` — add the two UART pins.
- `build.tcl` — point `top` at `coremark_top`; report timing + utilization.

---

## Phase 0 — Memory & bus groundwork

### Task 1: Grow the memories and let data memory preload an image

**Files:** Modify `rtl/instr_memory.sv`, `rtl/data_memory.sv`.

- [ ] **Step 1: Bump instruction memory depth.** In `rtl/instr_memory.sv` change
  `parameter int DEPTH = 4096,` → `parameter int DEPTH = 16384,`.

- [ ] **Step 2: Bump + preload data memory.** In `rtl/data_memory.sv`:
  - change `parameter int DEPTH = 4096` → `parameter int DEPTH = 16384`, and add
    `parameter string INIT_FILE = ""` to the parameter list.
  - after the `logic [31:0] mem [0:DEPTH-1];` declaration, add:

```systemverilog
    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end
```

  - confirm the word index uses `addr[15:2]` (with DEPTH=16384 you need 14 index bits).
    If it currently slices fewer bits, widen it to `addr[15:2]`.

- [ ] **Step 3: Regression — rv32ui still green.** The tests don't set `INIT_FILE`, so
  data memory is uninitialized exactly as before.

Run: `bash tests/build.sh && bash tests/run.sh`
Expected: `rv32ui: N passed, 0 failed` (same N as before this task).

- [ ] **Step 4: Commit.**

```bash
git add rtl/instr_memory.sv rtl/data_memory.sv
git commit -m "rtl: grow memories to 16K words, add data_memory INIT_FILE"
```

### Task 2: MMIO address decode in cpu_top (peripherals stubbed)

**Files:** Modify `rtl/cpu_top.sv`.

- [ ] **Step 1: Add the new top-level ports.** Extend the `cpu_top` port list with:

```systemverilog
    output logic        uart_tx,   // serial line out (idle high)
    output logic        halt       // pulses when SW writes HALT register
```

- [ ] **Step 2: Decode + gate the data path.** Today data memory is wired as the only
  load/store target. Replace that single instantiation with a decoded bus. Add near the
  other wires:

```systemverilog
    // ---- MMIO decode ----
    localparam logic [31:0] UART_DATA = 32'h1000_0000;
    localparam logic [31:0] UART_STAT = 32'h1000_0004;
    localparam logic [31:0] CYC_CTR   = 32'h1000_0008;
    localparam logic [31:0] HALT_REG  = 32'h1000_000C;

    logic        is_mmio;
    logic [31:0] dmem_rdata, mmio_rdata;
    logic        dmem_we;          // write enable that actually reaches the RAM

    assign is_mmio = alu_result[28];          // 0x1000_0000+ ⇒ peripherals
    assign dmem_we = mem_write & ~is_mmio;    // RAM writes only when NOT mmio
```

  Change the `data_memory` instance to use `dmem_we` and `dmem_rdata`:

```systemverilog
    data_memory #(.INIT_FILE("")) u_dmem (
        .clk(clk), .mem_write(dmem_we), .byte_en(dmem_be),
        .addr(alu_result), .write_data(dmem_wdata), .read_data(dmem_rdata) );
```

  And select what the load path sees:

```systemverilog
    assign mem_rdata = is_mmio ? mmio_rdata : dmem_rdata;
```

  (`mem_rdata` then flows through your existing `load_extend` unchanged.)

- [ ] **Step 3: Stub the peripherals (filled in Phase 1).** For now:

```systemverilog
    assign mmio_rdata = 32'd0;
    assign uart_tx    = 1'b1;     // idle high
    assign halt       = mem_write & is_mmio & (alu_result == HALT_REG);
```

- [ ] **Step 4: Regression.** Run: `bash tests/run.sh`
Expected: same pass count as Task 1 (MMIO path is dead code for the ISA tests).

- [ ] **Step 5: Commit.**

```bash
git add rtl/cpu_top.sv
git commit -m "rtl(cpu_top): add MMIO decode, uart_tx/halt ports (peripherals stubbed)"
```

---

## Phase 1 — Peripherals (you write the modules)

### Task 3: `cycle_counter` — the time source

**Files:** Create `rtl/cycle_counter.sv`; Test `tb/cycle_counter_tb.sv` (below).

**Contract — `cycle_counter(clk, rst_n) -> count`**
A 32-bit register that resets to 0 and increments by 1 every rising clock edge after reset.
That's the whole module. Read it via the bus at `CYC_CTR`.

- [ ] **Step 1: Read the testbench (the spec).** Create `tb/cycle_counter_tb.sv`:

```systemverilog
`timescale 1ns/1ps
module cycle_counter_tb;
    logic clk = 0, rst_n;
    logic [31:0] count;
    cycle_counter dut (.clk(clk), .rst_n(rst_n), .count(count));
    always #5 clk = ~clk;            // 100 MHz

    int errors = 0;
    task check(input [31:0] got, exp, input string what);
        if (got !== exp) begin $display("FAIL %s: got %0d exp %0d", what, got, exp); errors++; end
    endtask

    initial begin
        rst_n = 0; @(posedge clk); #1; check(count, 0, "reset=0");
        rst_n = 1;
        repeat (10) @(posedge clk); #1; check(count, 10, "after 10 clks");
        repeat (5)  @(posedge clk); #1; check(count, 15, "after 15 clks");
        if (errors == 0) $display("cycle_counter : ALL TESTS PASSED");
        else             $display("cycle_counter : %0d FAILURES", errors);
        $finish;
    end
endmodule
```

- [ ] **Step 2: Write `rtl/cycle_counter.sv` yourself** to satisfy that contract
  (one `always_ff`, synchronous reset to 0, else `count <= count + 1`).

- [ ] **Step 3: Run it.**
Run: `iverilog -g2012 -o build/cyc.vvp rtl/cycle_counter.sv tb/cycle_counter_tb.sv && vvp build/cyc.vvp`
Expected: `cycle_counter : ALL TESTS PASSED`

- [ ] **Step 4: Commit.**

```bash
git add rtl/cycle_counter.sv tb/cycle_counter_tb.sv
git commit -m "rtl: cycle_counter (free-running 32-bit timer) + tb"
```

### Task 4: `uart_tx` — memory-mapped serial output

**Files:** Create `rtl/uart_tx.sv`; Test `tb/uart_tx_tb.sv` (below).
**Detailed how-to:** your `write-a-guide` fork — protocol, FSM, baud math step by step.

**Contract — `uart_tx #(CLK_FREQ, BAUD) (clk, rst_n, tx_start, tx_data[7:0]) -> tx, tx_busy`**
- `CLKS_PER_BIT = CLK_FREQ / BAUD` (100e6 / 115200 = 868).
- Idle: `tx = 1`, `tx_busy = 0`.
- On a 1-cycle `tx_start` pulse while not busy: latch `tx_data`, raise `tx_busy`, then emit
  **8N1**: start bit `0`, 8 data bits **LSB first**, stop bit `1` — each held `CLKS_PER_BIT`
  clocks. Drop `tx_busy` when the stop bit completes.
- `tx_start` is ignored while `tx_busy` (software polls `UART_STATUS` first).

- [ ] **Step 1: Read the testbench (the spec).** Create `tb/uart_tx_tb.sv` — it transmits a
  byte, then **receives** it with an independent oversampling model and checks equality:

```systemverilog
`timescale 1ns/1ps
module uart_tx_tb;
    localparam int CLK_FREQ = 100_000_000, BAUD = 115200;
    localparam int CPB = CLK_FREQ / BAUD;                 // clocks per bit
    logic clk = 0, rst_n = 0, tx_start = 0; logic [7:0] tx_data; logic tx, tx_busy;
    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) dut
        (.clk(clk), .rst_n(rst_n), .tx_start(tx_start), .tx_data(tx_data), .tx(tx), .tx_busy(tx_busy));
    always #5 clk = ~clk;

    // independent receiver: sample in the middle of each bit
    logic [7:0] rx; int errors = 0;
    task automatic receive(output [7:0] b);
        @(negedge tx);                       // start bit
        repeat (CPB + CPB/2) @(posedge clk); // center of bit0
        for (int i = 0; i < 8; i++) begin b[i] = tx; repeat (CPB) @(posedge clk); end
    endtask
    task automatic send_check(input [7:0] v);
        @(posedge clk); tx_data = v; tx_start = 1; @(posedge clk); tx_start = 0;
        receive(rx);
        if (rx !== v) begin $display("FAIL: sent %02x got %02x", v, rx); errors++; end
        wait (!tx_busy); repeat (CPB) @(posedge clk);
    endtask
    initial begin
        repeat (4) @(posedge clk); rst_n = 1;
        send_check(8'h41); send_check(8'h55); send_check(8'h00); send_check(8'hFF);
        if (errors == 0) $display("uart_tx : ALL TESTS PASSED");
        else             $display("uart_tx : %0d FAILURES", errors);
        $finish;
    end
endmodule
```

- [ ] **Step 2: Write `rtl/uart_tx.sv` yourself** (follow the fork guide — FSM with a
  `CLKS_PER_BIT` down-counter and a 0..9 bit index, or a shift register with a sentinel).

- [ ] **Step 3: Run it.**
Run: `iverilog -g2012 -o build/uart.vvp rtl/uart_tx.sv tb/uart_tx_tb.sv && vvp build/uart.vvp`
Expected: `uart_tx : ALL TESTS PASSED`

- [ ] **Step 4: Commit.**

```bash
git add rtl/uart_tx.sv tb/uart_tx_tb.sv
git commit -m "rtl: uart_tx (115200-8N1 TX) + self-checking tb"
```

### Task 5: Wire peripherals into cpu_top + SoC smoke test

**Files:** Modify `rtl/cpu_top.sv`; Test `tb/soc_smoke_tb.sv`.

- [ ] **Step 1: Replace the Task-2 stubs with real peripherals.** In `cpu_top`:

```systemverilog
    // free-running time source
    logic [31:0] cycles;
    cycle_counter u_cyc (.clk(clk), .rst_n(rst_n), .count(cycles));

    // serial out
    logic        uart_start, uart_busy;
    assign uart_start = mem_write & is_mmio & (alu_result == UART_DATA);
    uart_tx #(.CLK_FREQ(100_000_000), .BAUD(115200)) u_uart (
        .clk(clk), .rst_n(rst_n),
        .tx_start(uart_start), .tx_data(dmem_wdata[7:0]),
        .tx(uart_tx), .tx_busy(uart_busy) );

    // MMIO read mux (combinational, single-cycle load)
    always_comb begin
        case (alu_result[3:2])
            2'd1:    mmio_rdata = {31'd0, uart_busy};   // UART_STATUS
            2'd2:    mmio_rdata = cycles;               // CYCLE_COUNTER
            default: mmio_rdata = 32'd0;
        endcase
    end
```

  Delete the Task-2 `assign uart_tx = 1'b1;` and `assign mmio_rdata = 32'd0;` stubs.
  Keep the `halt` assignment from Task 2.

- [ ] **Step 2: Smoke-test program + testbench.** Create `tb/soc_smoke_tb.sv` that runs a
  hand-written hex which: reads `CYCLE_COUNTER`, then writes `'H' 'i' '\n'` to `UART_DATA`
  (polling `UART_STATUS` between bytes), then writes `HALT`. The testbench instantiates
  `cpu_top`, decodes `uart_tx` with the same receiver task as Task 4, and asserts it sees
  `"Hi\n"` before `halt`. *(I'll generate `tb/soc_smoke_tb.sv` + `programs/smoke.hex` when
  you reach this step — it depends on the final register numbers above.)*

- [ ] **Step 3: Run + regression.**
Run: `bash tests/run.sh` (rv32ui unaffected) then the smoke tb.
Expected: rv32ui pass count unchanged; `soc_smoke : ALL TESTS PASSED`.

- [ ] **Step 4: Commit.**

```bash
git add rtl/cpu_top.sv tb/soc_smoke_tb.sv programs/smoke.hex
git commit -m "rtl(cpu_top): wire cycle_counter + uart_tx; SoC smoke test"
```

---

## Phase 2 — CoreMark software port

> **STATUS:** Tasks 6 and 8 are largely **done** — `bench/cc.sh`, `crt0.S`, `link.ld`,
> `mmio.h`, and `hello.c`/`hello.hex` already exist (compile-script fork). What remains in
> this phase: actually *run* `hello.hex` in sim (needs Phase 1's SoC), and write the
> CoreMark port (`core_portme.*`) + vendor the sources, then build with `cc.sh`.

### Task 6: Linker script + crt0 + a "hello UART" program — ✅ files exist; just validate

**Files:** Create `bench/port/link.ld`, `bench/port/crt0.S`, `bench/hello/hello.c`,
`bench/port/mmio.h`.

We validate startup, the unified-image linker, and the UART **before** dragging CoreMark in.

- [ ] **Step 1: `bench/port/link.ld`** — one image at `0x0`, stack at top of 64 KiB:

```ld
OUTPUT_ARCH("riscv")
ENTRY(_start)
MEMORY { RAM : ORIGIN = 0x00000000, LENGTH = 64K }
SECTIONS {
  .text.init : { *(.text.init) } > RAM
  .text   : { *(.text) *(.text.*) } > RAM
  .rodata : { *(.rodata) *(.rodata.*) *(.srodata*) } > RAM
  .data   : { *(.data) *(.data.*) *(.sdata*) } > RAM
  .bss    : { __bss_start = .; *(.bss) *(.sbss*) *(COMMON) } > RAM
  . = ALIGN(4); __bss_end = .;
  _stack_top = ORIGIN(RAM) + LENGTH(RAM) - 16;   /* 0x0000FFF0 */
}
```

- [ ] **Step 2: `bench/port/crt0.S`** — set sp, zero bss, call main, then HALT:

```asm
    .section .text.init
    .globl _start
_start:
    la   sp, _stack_top
    la   t0, __bss_start
    la   t1, __bss_end
1:  bge  t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:  call main
    li   t0, 0x1000000C        # HALT register
    sw   zero, 0(t0)
3:  j    3b
```

- [ ] **Step 3: `bench/port/mmio.h`** — the device handles software uses:

```c
#ifndef MMIO_H
#define MMIO_H
#define UART_DATA (*(volatile unsigned int *)0x10000000u)
#define UART_STAT (*(volatile unsigned int *)0x10000004u)
#define CYCLES    (*(volatile unsigned int *)0x10000008u)
static inline void uart_putc(char c){ while(UART_STAT & 1u){} UART_DATA=(unsigned char)c; }
static inline unsigned cycles(void){ return CYCLES; }
#endif
```

- [ ] **Step 4: `bench/hello/hello.c`.**

```c
#include "mmio.h"
int main(void){ const char *s="Hello from RV32I\n"; while(*s) uart_putc(*s++); return 0; }
```

- [ ] **Step 5: Build + run in the existing sim path** (reuse `bin2hex.py`):

```bash
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -O2 -nostdlib -nostartfiles \
  -Ibench/port -Tbench/port/link.ld bench/port/crt0.S bench/hello/hello.c -o build/hello.elf
riscv64-unknown-elf-objcopy -O binary build/hello.elf build/hello.bin
python3 tests/bin2hex.py build/hello.bin programs/hello.hex
```

  Then run a tb that loads `programs/hello.hex` into both memories and prints UART bytes.
  *(I'll provide `tb/uart_run_tb.sv` — a generic "load hex, echo UART to console, stop on
  halt" harness reused for CoreMark.)*
Expected console: `Hello from RV32I`.

- [ ] **Step 6: Commit.**

```bash
git add bench/port bench/hello programs/hello.hex tb/uart_run_tb.sv
git commit -m "bench: linker+crt0+mmio, hello-UART bring-up program"
```

### Task 7: Vendor CoreMark + write the port layer

**Files:** Create `bench/coremark/` (vendored), `bench/port/core_portme.h`,
`bench/port/core_portme.c`.

- [ ] **Step 1: Fetch CoreMark.**

```bash
git clone https://github.com/eembc/coremark bench/coremark-src
cp bench/coremark-src/{core_main.c,core_list_join.c,core_matrix.c,core_state.c,core_util.c,coremark.h} bench/coremark/
cp bench/coremark-src/barebones/ee_printf.c bench/coremark/
```

- [ ] **Step 2: `bench/port/core_portme.h`** — key knobs:

```c
#ifndef CORE_PORTME_H
#define CORE_PORTME_H
#define HAS_FLOAT 0
#define HAS_TIME_H 0
#define USE_CLOCK 0
#define HAS_STDIO 0
#define HAS_PRINTF 0            /* use CoreMark's ee_printf -> our uart_putc */
#define COMPILER_FLAGS "-O2 -march=rv32i -mabi=ilp32"
#define MEM_METHOD MEM_STACK   /* no malloc; data on the stack */
#define MULTITHREAD 1
#define MAIN_HAS_NOARGC 1
#define SEED_METHOD SEED_VOLATILE
typedef unsigned int CORE_TICKS;
#define CLOCKS_PER_SEC 100000000u    /* 1 tick = 1 CPU cycle */
void start_time(void); void stop_time(void); CORE_TICKS get_time(void);
double time_in_secs(CORE_TICKS ticks);
#define COMPILER_VERSION "gcc rv32i"
#endif
```

- [ ] **Step 3: `bench/port/core_portme.c`** — timing via the cycle counter, output via UART:

```c
#include "coremark.h"
#include "core_portme.h"
#include "mmio.h"
static CORE_TICKS t0, t1;
void start_time(void){ t0 = cycles(); }
void stop_time(void){ t1 = cycles(); }
CORE_TICKS get_time(void){ return t1 - t0; }
double time_in_secs(CORE_TICKS ticks){ return (double)ticks / (double)CLOCKS_PER_SEC; }
void portable_init(core_portable *p, int *argc, char *argv[]){ (void)argc;(void)argv; p->portable_id=1; }
void portable_fini(core_portable *p){ p->portable_id=0; }
/* CoreMark's ee_printf calls this for every character */
void uart_send_char(char c){ uart_putc(c); }
```

- [ ] **Step 4: Commit.**

```bash
git add bench/coremark bench/port/core_portme.*
git commit -m "bench: vendor CoreMark + RV32I port (cycle-counter timing, UART output)"
```

### Task 8: Build CoreMark to a hex image — use the existing `bench/cc.sh`

No new build script needed — `bench/cc.sh` already does compile → ELF → hex with the size
guard. Just point it at the CoreMark sources + port.

- [ ] **Step 1: Build CoreMark.** `ITERATIONS` small for sim, large for board:

Run:
```bash
bench/cc.sh -o coremark bench/coremark/core_*.c bench/coremark/ee_printf.c \
  bench/port/core_portme.c \
  -Ibench/coremark -DITERATIONS=1 -DPERFORMANCE_RUN=1 '-DFLAGS_STR="-O2"'
```
Expected: `built programs/coremark.hex  <N> words (...)  entry=0x0` with N ≤ 16384.
If it prints the "IMAGE TOO BIG" warning and exits, bump `DEPTH` to 32768 in both memories
and re-run Task 1's regression.

- [ ] **Step 2: Commit.**

```bash
git add bench/coremark bench/port/core_portme.* programs/coremark.hex
git commit -m "bench: build CoreMark via cc.sh -> coremark.hex"
```

---

## Phase 3 — Simulation run

### Task 9: Run CoreMark in simulation, capture the score

**Files:** Create `tb/coremark_tb.sv` (I provide; it's `uart_run_tb` + a cycle report).

- [ ] **Step 1: The harness** loads `programs/coremark.hex` into `instr_memory` **and**
  `data_memory` (via `INIT_FILE`), drives a 100 MHz clock, echoes every UART byte to the
  console with `$write`, counts clocks, and `$finish`es on `halt`.

```systemverilog
`timescale 1ns/1ps
module coremark_tb;
  logic clk = 0, rst_n = 0, uart_tx, halt;
  localparam string IMG = "/home/vr-pc/Documents/mahmoud/riscv-core/programs/coremark.hex";
  // imem via INIT_FILE param, dmem via INIT_FILE param — both = IMG
  cpu_top #(.INIT_FILE(IMG)) u_cpu (.clk(clk), .rst_n(rst_n),
      .uart_tx(uart_tx), .halt(halt) /* + debug taps tied off */);
  // NOTE: also pass IMG into the data_memory INIT_FILE (param override in cpu_top)
  always #5 clk = ~clk;
  // UART receiver (same task as uart_tx_tb) -> $write(byte); count cycles; stop on halt
  // ... I'll fill the receiver + cycle counter + summary print when you reach this step
endmodule
```

  *(The one wrinkle I'll handle here: `cpu_top` currently hardcodes the dmem `INIT_FILE("")`.
  I'll thread `cpu_top`'s `INIT_FILE` parameter into `u_dmem` so one param loads both
  memories.)*

- [ ] **Step 2: Run.**
Run: `iverilog -g2012 -o build/cm.vvp $(ls rtl/*.sv | grep -vE 'nexys4_top|coremark_top|clock_divider') tb/coremark_tb.sv && vvp build/cm.vvp`
Expected console (CoreMark's own output): a `CoreMark 1.0 : ... / ...` line, the seeds, and
crucially **`Correct operation validated. See README.md for run and reporting rules.`**
plus the testbench's `cycles = <C>` line.

- [ ] **Step 3: Compute the number.** CoreMark/MHz = `iterations / (cycles / 1e6)` ÷ `(F/1e6)`
  — but since 1 tick = 1 cycle, the clean, clock-independent figure is
  **CoreMark/MHz = ITERATIONS × 1e6 / cycles**. Record it. (Bump `ITER` if you want a longer,
  more representative run; CRC stays valid.)

- [ ] **Step 4: Commit.**

```bash
git add tb/coremark_tb.sv rtl/cpu_top.sv
git commit -m "sim: run CoreMark, capture CRC validation + cycle count"
```

---

## Phase 4 — Board bring-up

### Task 10: Full-speed board top + UART pins

**Files:** Create `rtl/coremark_top.sv`; Modify `constraints/nexys4.xdc`.

- [ ] **Step 1: `rtl/coremark_top.sv`** — run the CPU on the real clock (no slow divider),
  drive the board's UART TX pin, reset on the red button. Optionally show `cycles[31:16]`
  on the LEDs as a "still running" heartbeat.

```systemverilog
module coremark_top (
    input  logic CLK100MHZ,
    input  logic CPU_RESETN,       // red button, active-low
    output logic UART_RXD_OUT,     // FPGA -> host serial
    output logic [15:0] LED
);
    logic [31:0] dbg_pc, dbg_res; logic dbg_rw; logic [4:0] dbg_rd;
    logic uart_tx, halt;
    cpu_top #(.INIT_FILE("programs/coremark.hex")) u_cpu (
        .clk(CLK100MHZ), .rst_n(CPU_RESETN),
        .debug_pc(dbg_pc), .debug_reg_write(dbg_rw), .debug_rd(dbg_rd), .debug_result(dbg_res),
        .uart_tx(uart_tx), .halt(halt));
    assign UART_RXD_OUT = uart_tx;
    assign LED = dbg_pc[15:0];
endmodule
```

  *(For synthesis, load the hex into the BRAMs via the memories' `$readmemh` init — confirm
  Vivado picks up `programs/coremark.hex`; use an absolute path or add it to the project as
  a memory-init file.)*

- [ ] **Step 2: Add the UART pins to `constraints/nexys4.xdc`.** Confirm the exact pins from
  your master file first:

```bash
grep -iE "uart" constraints/Nexys-4-Master.xdc
```

  Then add (Nexys 4 / Nexys 4 DDR USB-UART — FPGA TX is `uart_rxd_out`):

```tcl
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports {UART_RXD_OUT}]
## (UART_TXD_IN on C4 is host->FPGA RX; not needed for TX-only output)
```

- [ ] **Step 3: Commit.**

```bash
git add rtl/coremark_top.sv constraints/nexys4.xdc
git commit -m "board: full-speed coremark_top + UART pin"
```

### Task 11: Synthesize, get Fmax + utilization, flash, capture

**Files:** Modify `build.tcl`.

- [ ] **Step 1: Point `build.tcl` at `coremark_top`** as the synthesis top, add the new RTL
  (`uart_tx.sv`, `cycle_counter.sv`), keep `nexys4.xdc`. Run synth + implementation.

- [ ] **Step 2: Read the numbers.** After implementation:
  - **Utilization:** `report_utilization` → LUTs, FFs, BRAM tiles (and % of XC7A100T).
  - **Fmax:** set the `CLK100MHZ` period constraint, read **WNS** from `report_timing_summary`;
    `Fmax ≈ 1 / (T - WNS)`. Tighten the period until WNS ≈ 0 to find the true max.

- [ ] **Step 3: Flash + capture UART on your PC.**

```bash
# find the port (usually the second FTDI interface), then:
picocom -b 115200 /dev/ttyUSB1      # or: screen /dev/ttyUSB1 115200
```

  Press the red reset button; you should see the **same CoreMark output + CRC validation**
  as in sim. Record board cycles → CoreMark, and CoreMark = CoreMark/MHz × (Fmax in MHz).

- [ ] **Step 4: Write up results.** Add a short `docs/results.md` (and a README bullet):
  CoreMark/MHz, Fmax, CoreMark @ Fmax, LUT/FF/BRAM utilization, CRC validated. This is the
  résumé line.

- [ ] **Step 5: Commit.**

```bash
git add build.tcl docs/results.md README.md
git commit -m "board: CoreMark on Nexys 4 — Fmax, utilization, validated score"
```

---

## Verification gates (don't pass one with the previous broken)

1. **Task 1–2, 5:** `bash tests/run.sh` rv32ui pass count never regresses.
2. **Task 9:** CoreMark prints **`Correct operation validated`** (CRC match) in sim.
3. **Task 9:** sim cycle count → CoreMark/MHz recorded.
4. **Task 11:** board prints the same CRC validation; Fmax + utilization captured.

## Honesty note for the résumé
This is a **CRC-validated, representative** CoreMark run (fixed iteration count on a soft
core), not an official EEMBC submission. Report it as "CoreMark/MHz on a self-built RV32I
core, validated by CoreMark's CRC self-check," with Fmax and utilization — all true and
defensible in an interview.
