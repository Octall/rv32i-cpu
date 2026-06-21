// =============================================================================
// test_runner.sv  --  runs a compiled riscv-test hex on the core, checks tohost
// =============================================================================
// Plusargs:
//   +HEX=<file>      the test image ($readmemh words)
//   +TOHOST=<hex>    byte address of the `tohost` word (default 0x510)
//
// The core is Harvard (separate instr/data memories), but the riscv-tests are a
// single unified image, so we load the SAME image into BOTH memories: code is
// fetched from u_imem, data/tohost live in u_dmem. We watch the tohost word:
//   1 -> PASS ; (N<<1)|1 -> FAIL at sub-test N ; never written -> timeout.
// =============================================================================
`timescale 1ns/1ps

module test_runner;
    logic        clk = 0, rst_n;
    logic [31:0] debug_pc, debug_result;
    logic        debug_reg_write;
    logic [4:0]  debug_rd;
    logic        uart_tx, halt;     // cpu_top's new MMIO outputs (for .* elaboration)

    cpu_top dut (.*);
    always #5 clk = ~clk;

    string       hexfile;
    int          tohost_byte, tohost_word, i;
    logic [31:0] t;

    initial begin
        rst_n = 0;
        if (!$value$plusargs("HEX=%s", hexfile)) begin
            $display("ERROR: pass +HEX=<file>"); $finish;
        end
        if (!$value$plusargs("TOHOST=%h", tohost_byte)) tohost_byte = 'h510;
        tohost_word = tohost_byte >> 2;

        #1;  // let instr_memory's own initial $readmemh run first, then override
        $readmemh(hexfile, dut.u_imem.mem);
        $readmemh(hexfile, dut.u_dmem.mem);

        @(posedge clk); @(negedge clk); rst_n = 1;

        t = 0;
        i = 0;
        while (i < 200000 && t === 32'd0) begin
            @(negedge clk);
            t = dut.u_dmem.mem[tohost_word];
            i = i + 1;
        end

        if (t === 32'd1)
            $display("PASS  %s", hexfile);
        else if (t === 32'd0)
            $display("FAIL  %s  (timeout -- tohost never written, %0d cycles)", hexfile, i);
        else
            $display("FAIL  %s  (sub-test %0d, tohost=0x%08x)", hexfile, t >> 1, t);
        $finish;
    end
endmodule
