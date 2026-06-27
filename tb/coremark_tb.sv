// =============================================================================
// coremark_tb.sv  --  run CoreMark on the core in simulation
// =============================================================================
// Loads programs/coremark.hex into both Harvard memories, clocks the core,
// echoes every UART byte to the console (so you see CoreMark's own report and
// its "Correct operation validated" CRC line), counts clock cycles, and stops
// when the program writes the HALT register. Prints the total cycle count so
// you can compute CoreMark/MHz = ITERATIONS * 1e6 / cycles.
//
// CoreMark in sim is long-running (millions of cycles even for 1 iteration with
// software mul/div on RV32I), so the watchdog is generous. Run headless:
//   iverilog -g2012 -o build/cm.vvp \
//       $(ls rtl/*.sv | grep -vE 'nexys4_top|board_top|clock_divider') tb/coremark_tb.sv
//   vvp build/cm.vvp
// =============================================================================
`timescale 1ns/1ps

module coremark_tb;
    localparam int CPB = 100_000_000 / 115_200;     // UART clocks per bit at sim's 100 MHz
    localparam string IMG = "/home/vr-pc/Documents/mahmoud/riscv-core/programs/coremark.hex";

    logic        clk = 0, rst_n;
    logic [31:0] debug_pc, debug_result;
    logic        debug_reg_write;
    logic [4:0]  debug_rd;
    logic        uart_tx, halt;

    cpu_top dut (.*);
    always #5 clk = ~clk;                            // 100 MHz

    longint unsigned cycles = 0;
    always @(posedge clk) if (rst_n) cycles <= cycles + 1;

    // continuous UART receiver -> echo each decoded byte to the console
    logic [7:0] b;
    initial begin : uart_monitor
        forever begin
            @(negedge uart_tx);
            repeat (CPB + CPB/2) @(posedge clk);
            for (int i = 0; i < 8; i++) begin
                b[i] = uart_tx;
                repeat (CPB) @(posedge clk);
            end
            $write("%c", b);
        end
    end

    initial begin
        rst_n = 0;
        #1;
        $readmemh(IMG, dut.u_imem.mem);
        $readmemh(IMG, dut.u_dmem.mem);
        @(posedge clk); @(negedge clk); rst_n = 1;

        wait (halt);
        repeat (20 * CPB) @(posedge clk);            // drain final UART output
        $display("\n[coremark_tb] HALT reached after %0d cycles", cycles);
        $display("[coremark_tb] CoreMark/MHz = ITERATIONS * 1e6 / %0d", cycles);
        $finish;
    end

    // generous watchdog (CoreMark is millions of cycles); raise if it trips early
    initial begin
        #2_000_000_000;                              // 2 ms sim time ... bump if needed
        $display("\n[coremark_tb] WATCHDOG TIMEOUT at %0d cycles (raise the limit)", cycles);
        $finish;
    end
endmodule
