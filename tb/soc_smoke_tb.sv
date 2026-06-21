// =============================================================================
// soc_smoke_tb.sv  --  end-to-end SoC test: CPU + bus + uart_tx + cycle_counter
// =============================================================================
// Loads the prebuilt hello program (programs/hello.hex) into both Harvard
// memories, runs the core, decodes the serial line, and checks the bytes equal
// "Hello from RV32I\n". The program also writes the HALT register on exit, which
// asserts cpu_top.halt and lets us stop. Proves the whole Phase-1 datapath:
// store->UART, UART_STATUS polling, and the HALT decode all work together.
// =============================================================================
`timescale 1ns/1ps

module soc_smoke_tb;
    localparam int CPB = 100_000_000 / 115_200;     // clocks per UART bit (868)
    localparam string IMG = "/home/vr-pc/Documents/mahmoud/riscv-core/programs/hello.hex";
    // expected output packed into a vector (Icarus string methods are unreliable);
    // char i lives at EXP[(LEN-1-i)*8 +: 8]
    localparam int LEN = 17;
    localparam logic [LEN*8-1:0] EXP = "Hello from RV32I\n";

    logic        clk = 0, rst_n;
    logic [31:0] debug_pc, debug_result;
    logic        debug_reg_write;
    logic [4:0]  debug_rd;
    logic        uart_tx, halt;

    cpu_top dut (.*);
    always #5 clk = ~clk;

    int idx = 0, errors = 0;
    logic [7:0] b;

    // continuous UART receiver: decode every byte on the line, check vs EXP
    initial begin : uart_monitor
        forever begin
            @(negedge uart_tx);                     // start bit
            repeat (CPB + CPB/2) @(posedge clk);    // land mid data-bit 0
            for (int i = 0; i < 8; i++) begin
                b[i] = uart_tx;
                repeat (CPB) @(posedge clk);
            end
            $write("%c", b);                        // echo live
            if (idx < LEN) begin
                if (b !== EXP[(LEN-1-idx)*8 +: 8]) begin
                    $display("\nFAIL char %0d: got %02x exp %02x", idx, b, EXP[(LEN-1-idx)*8 +: 8]);
                    errors++;
                end
            end else errors++;                      // unexpected extra byte
            idx++;
        end
    end

    // load program into both memories (same trick as test_runner) and run
    initial begin
        rst_n = 0;
        #1;
        $readmemh(IMG, dut.u_imem.mem);
        $readmemh(IMG, dut.u_dmem.mem);
        @(posedge clk); @(negedge clk); rst_n = 1;

        wait (halt);                                // program reached exit
        repeat (30 * CPB) @(posedge clk);           // let the final char(s) drain

        if (errors == 0 && idx == LEN)
            $display("\nsoc_smoke : ALL TESTS PASSED (%0d chars)", idx);
        else
            $display("\nsoc_smoke : FAIL (errors=%0d, chars=%0d/%0d)", errors, idx, LEN);
        $finish;
    end

    // watchdog
    initial begin
        #10_000_000;
        $display("\nsoc_smoke : TIMEOUT (got %0d chars)", idx);
        $finish;
    end
endmodule
