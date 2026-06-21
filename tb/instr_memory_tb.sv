// =============================================================================
// instr_memory_tb.sv  --  the SPEC for the instruction ROM. Do NOT edit this.
// =============================================================================
// Run with:  make sim TB=instr_memory
// It loads programs/imem_test.hex into the ROM and checks that each byte
// address returns the right word.
// =============================================================================
`timescale 1ns/1ps

module instr_memory_tb;

    logic [31:0] addr;
    logic [31:0] instr;

    int errors = 0;

    // Load the known test program. Path is relative to where `make` runs
    // (the project root).
    instr_memory #(
        .DEPTH(256),
        .INIT_FILE("programs/imem_test.hex")
    ) dut (.*);

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got !== exp) begin
            $display("  FAIL %-14s got 0x%08x  expected 0x%08x", name, got, exp);
            errors++;
        end else begin
            $display("  ok   %-14s 0x%08x", name, got);
        end
    endtask

    initial begin
        $dumpfile("instr_memory_tb.vcd");
        $dumpvars(0, instr_memory_tb);

        // Each instruction sits one word (4 bytes) after the previous one.
        addr = 32'd0;  #1; check("instr @ 0",  instr, 32'h00000093);
        addr = 32'd4;  #1; check("instr @ 4",  instr, 32'h00100113);
        addr = 32'd8;  #1; check("instr @ 8",  instr, 32'h00200193);
        addr = 32'd12; #1; check("instr @ 12", instr, 32'hdeadbeef);
        addr = 32'd16; #1; check("instr @ 16", instr, 32'hcafef00d);

        if (errors == 0) $display("INSTR MEMORY: ALL TESTS PASSED");
        else             $display("INSTR MEMORY: %0d FAILURE(S)", errors);
        $finish;
    end

endmodule
