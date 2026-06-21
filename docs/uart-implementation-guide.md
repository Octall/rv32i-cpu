# Guide: Implementing the UART (for CoreMark output)

A memory-mapped **UART transmitter** so the core can print CoreMark's results to your
PC over the Nexys 4's USB-serial bridge. TX is all CoreMark needs (it only prints);
RX is sketched at the end as optional.

This is written against *your* code: single-cycle RV32I, Harvard memory, stores driven
by `store_align`/`alu_result` in `cpu_top.sv`, loads returning through `load_extend`.

---

## 1. How the hardware path works

The Nexys 4 has an FTDI USB-UART bridge. From the Digilent master XDC:

| Sch name        | Package pin | Direction (FPGA's view) | Master-XDC port |
|-----------------|-------------|--------------------------|-----------------|
| `UART_RXD_OUT`  | **D4**      | **FPGA → host (TX)**      | `RsTx`          |
| `UART_TXD_IN`   | C4          | host → FPGA (RX)          | `RsRx`          |

So **you drive D4** to transmit. (Driving C4 by mistake = total silence — the #1 bug.)

The line protocol is standard **8N1**, **LSB first**, line **idles high**:

```
idle  start   b0  b1  b2  b3  b4  b5  b6  b7   stop  idle
 1  |   0   |  d0  d1  d2  d3  d4  d5  d6  d7 |  1  |  1
     \_ high->low edge marks the start of a byte
```

Each bit lasts exactly one **baud period**. At 115200 baud the receiver expects a new
bit every `1/115200 s`; your job is to hold each bit on the wire for that long.

---

## 2. Register map (how software reaches it)

The UART lives in a memory-mapped I/O window, above the 64 KiB of data memory. Pick:

| Address        | Name        | Access | Meaning                                  |
|----------------|-------------|--------|------------------------------------------|
| `0x1000_0000`  | `UART_TX`   | store  | write a byte → transmit it               |
| `0x1000_0004`  | `UART_STAT` | load   | bit 0 = `tx_busy` (1 = still sending)    |

Software sends a char by polling `UART_STAT` until `busy==0`, then storing the byte to
`UART_TX`. Putting MMIO at `0x1000_0000` (top nibble = 1) makes the address decode a
one-bit test, and keeps it clear of data memory (`0x0000_0000`–`0x0000_FFFF`).

---

## 3. Baud-rate generator (the timing)

You need `DIV = clk_freq / baud` clock cycles per serial bit.

```
clk = 100 MHz, baud = 115200  ->  DIV = 100_000_000 / 115_200 = 868   (0.006% error, fine)
clk = 100 MHz, baud =   9600  ->  DIV = 10417                          (slower, very safe)
```

Make `CLK_HZ` and `BAUD` parameters and compute `DIV` with `localparam` — never hard-code
868. **Critical:** `CLK_HZ` must be the clock that actually feeds the UART. Your current
`nexys4_top` runs the CPU on a *divided* slow clock; for CoreMark you'll run the CPU+UART
at the full 100 MHz, so `CLK_HZ = 100_000_000`. If you ever change the CPU clock, the baud
divider changes with it.

---

## 4. `uart_tx.sv` — the transmitter

The clean implementation is a 10-bit shift register `{stop, data[7:0], start}` clocked out
one bit per `DIV` cycles, LSB first. Skeleton (fill in / adapt to your house style):

```systemverilog
module uart_tx #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD   = 115_200
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,   // 1-cycle pulse: begin sending `data` (ignored if busy)
    input  logic [7:0] data,    // byte to send (only sampled when start & !busy)
    output logic       tx,      // serial line -> drive to package pin D4 (idle high)
    output logic       busy     // 1 while a frame is in flight
);
    localparam int DIV = CLK_HZ / BAUD;        // clocks per bit
    localparam int CW  = $clog2(DIV);

    logic [CW-1:0] baud_cnt;
    logic [3:0]    bit_idx;     // counts the 10 bits sent (start + 8 data + stop)
    logic [9:0]    shifter;     // bit being sent is always shifter[0]

    assign tx = busy ? shifter[0] : 1'b1;      // line idles HIGH when not sending

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0; baud_cnt <= '0; bit_idx <= '0; shifter <= '1;
        end else if (!busy) begin
            if (start) begin
                shifter  <= {1'b1, data, 1'b0};  // {stop=1, data, start=0}, LSB(start) first
                busy     <= 1'b1;
                baud_cnt <= '0;
                bit_idx  <= '0;
            end
        end else begin
            if (baud_cnt == DIV-1) begin         // one bit-time elapsed
                baud_cnt <= '0;
                shifter  <= {1'b1, shifter[9:1]}; // shift next bit into [0], feed idle-high
                if (bit_idx == 4'd9) busy <= 1'b0; // all 10 bits done -> ready
                bit_idx  <= bit_idx + 1'b1;
            end else begin
                baud_cnt <= baud_cnt + 1'b1;
            end
        end
    end
endmodule
```

Why it works: on `start` the shifter loads with the **start bit (0) in position 0**, so `tx`
immediately drops — the start edge. Every `DIV` cycles it shifts right, presenting `d0,
d1, …, d7`, then the stop bit (1), each held for a full bit-time. After 10 bits `busy`
clears and `tx` returns to idle-high. `start` is ignored while `busy`, so software must
poll first (matches the register map).

---

## 5. Wiring it into `cpu_top.sv`

The store/load path today goes straight to `data_memory`. Add a small address decode so the
MMIO window peels off to the UART. Put the UART **inside `cpu_top`** (the bus is local
there) and expose one output port for the pin.

**a) New port** on `cpu_top`:
```systemverilog
output logic uart_tx,     // -> board pin D4
```

**b) Address decode + control** (the store address is `alu_result`, store data is
`rs2_data`, the write strobe is `mem_write`):
```systemverilog
localparam logic [31:0] UART_TX_ADDR   = 32'h1000_0000;
localparam logic [31:0] UART_STAT_ADDR = 32'h1000_0004;

wire is_mmio    = (alu_result[31:28] == 4'h1);                 // anything in 0x1xxx_xxxx
wire uart_we    = mem_write & is_mmio & (alu_result[3:0]==4'h0); // store to UART_TX
wire uart_busy;
```
`uart_we` is naturally a **one-cycle pulse** (single-cycle core: the next instruction's
address differs), which is exactly the `start` pulse the UART wants.

**c) Instantiate the UART:**
```systemverilog
uart_tx #(.CLK_HZ(100_000_000), .BAUD(115_200)) u_uart (
    .clk(clk), .rst_n(rst_n),
    .start(uart_we), .data(rs2_data[7:0]),
    .tx(uart_tx), .busy(uart_busy)
);
```

**d) Don't let an MMIO store also corrupt data memory** — gate its write enable:
```systemverilog
// was: .mem_write(mem_write)
data_memory u_dmem ( .clk(clk), .mem_write(mem_write & ~is_mmio), .byte_en(dmem_be),
                     .addr(alu_result), .write_data(dmem_wdata), .read_data(mem_rdata) );
```

**e) Mux the load value** so reading `UART_STAT` returns the busy flag. Feed `load_extend`
from the mux instead of raw `mem_rdata`:
```systemverilog
wire [31:0] uart_rdata = {31'b0, uart_busy};
wire [31:0] load_word  = is_mmio ? uart_rdata : mem_rdata;

// was: .word(mem_rdata)
load_extend u_lext ( .funct3(funct3), .addr_lo(alu_result[1:0]),
                     .word(load_word), .result(load_result) );
```

That's the whole integration: one decode, one mux, one gated write, one instance. No
changes to decode/ALU/regfile.

> Note: when you bump `data_memory`/`instr_memory` `DEPTH` to 16384 for CoreMark, the index
> inside `data_memory` widens from `addr[13:2]` to `addr[15:2]`. The MMIO test (`[31:28]`)
> is unaffected.

---

## 6. Board top + constraints

**`nexys4_top.sv`:** add the output and route it (run the CPU at full speed for CoreMark —
feed `CLK100MHZ`, not the slow divided clock):
```systemverilog
output logic UART_TX_PIN,
...
cpu_top u_cpu ( .clk(CLK100MHZ), .rst_n(CPU_RESETN), .uart_tx(UART_TX_PIN), /* debug taps */ );
```

**`constraints/nexys4.xdc`:** add the pin (TX only):
```tcl
## USB-UART: FPGA transmit -> host (Sch name UART_RXD_OUT)
set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 } [get_ports UART_TX_PIN]
```

---

## 7. Software side (the C hooks)

Minimal driver:
```c
#define UART_TX   (*(volatile unsigned int *)0x10000000)
#define UART_STAT (*(volatile unsigned int *)0x10000004)

void uart_putc(char c) {
    while (UART_STAT & 1u) { }     // wait until not busy
    UART_TX = (unsigned char)c;
}
void uart_puts(const char *s){ while (*s){ if(*s=='\n') uart_putc('\r'); uart_putc(*s++);} }
```
(The `\n`→`\r\n` translation keeps terminals tidy.)

**CoreMark hook:** CoreMark prints through its own `ee_printf`, which bottoms out in a
single character sink — implement that to call `uart_putc`:
```c
int uart_send_char(int ch) { uart_putc((char)ch); return ch; }
```
Wire `ee_printf`'s output to `uart_send_char` in `core_portme.c` (or `#define` CoreMark's
`printf` to `ee_printf`). This is the only output path CoreMark needs.

---

## 8. Testing — in this order

1. **Unit testbench** (`tb/uart_tx_tb.sv`, copy the self-checking style of your other TBs):
   instantiate with a *tiny* divider so sim is fast, e.g. `#(.CLK_HZ(1000), .BAUD(100))`
   → `DIV=10`. Pulse `start` with `data=8'h41` ('A'). Then **sample `tx` at the center of
   each bit** (wait `DIV/2` then every `DIV` cycles) and check: start=0, the 8 bits equal
   `0x41` LSB-first, stop=1, and `busy` rises on `start` and falls after the stop bit.
   `... : ALL TESTS PASSED` like the rest.

2. **Integration** in `cpu_top_tb`: run a 4-instruction program that stores `'H'` then `'i'`
   to `UART_TX` (polling `UART_STAT`). Add a serial-decoder `always` block in the TB that
   watches `u_cpu.uart_tx`, recovers bytes at the baud period, and `$write`s them — you
   should see `Hi`. This proves the whole bus path end-to-end in sim.

3. **On hardware:** after synth + flash, find the port (`dmesg | grep ttyUSB` — the FTDI
   exposes two channels; the UART is usually `/dev/ttyUSB1`) and open it **115200 8N1**:
   ```bash
   picocom -b 115200 /dev/ttyUSB1      # or:  screen /dev/ttyUSB1 115200
   ```
   A "hello" program should print before you even bother with CoreMark.

---

## 9. Pitfalls checklist

- [ ] Driving **D4** (FPGA TX), not C4. Backwards = silence.
- [ ] Line **idles high**; first transition is start (high→low).
- [ ] **LSB first.**
- [ ] `DIV` uses the **actual** UART clock (100 MHz at full speed, *not* the slow divided clock).
- [ ] **Poll `busy` before every write**, or characters get dropped.
- [ ] Add the pin to the XDC *and* declare the top-level port as `output`.
- [ ] Host terminal set to **115200 8N1**, no flow control.
- [ ] `start` is a 1-cycle pulse — your single-cycle store gives this for free; don't latch it.

---

## 10. Optional: add RX later

Only needed if you want the board to wait for a keypress before running. RX is harder than
TX because you must *recover* the timing:

- **Synchronize** the async input through two flip-flops (metastability).
- Detect the **start edge** (idle-high → low).
- Use **16× oversampling**: wait half a bit (`DIV/2`) to land mid-start-bit, confirm it's
  still low, then sample every `DIV` cycles for 8 data bits, check the stop bit is high.
- Expose `RX_DATA` / `RX_VALID` registers in the same MMIO window (e.g. `0x1000_0008`).
- Pin: **C4** (`UART_TXD_IN`), `IOSTANDARD LVCMOS33`.

---

## Suggested build order

1. `uart_tx.sv` + unit TB → framing correct in sim.
2. MMIO decode + UART instance + `uart_tx` port in `cpu_top` (gate dmem write, add status mux).
3. "Hi" program + `cpu_top_tb` serial decoder → end-to-end in sim.
4. XDC pin + board top at 100 MHz → synth, flash, `picocom` → real "hello".
5. Then port CoreMark and point `ee_printf` at `uart_putc`.
```
