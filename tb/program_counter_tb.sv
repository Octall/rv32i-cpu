// =============================================================================
// program_counter_tb.sv  --  the SPEC for your first task. Do NOT edit this.
// =============================================================================
// Run it with:  make sim TB=program_counter
// Make rtl/program_counter.sv pass every check below.
// =============================================================================
`timescale 1ns/1ps

module program_counter_tb;

    logic        clk = 0;
    logic        rst_n;
    logic        pc_load;
    logic [31:0] pc_next;
    logic [31:0] pc;

    int errors = 0;

    program_counter dut (.*);

    always #5 clk = ~clk;

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got !== exp) begin
            $display("  FAIL %-22s got 0x%08x  expected 0x%08x", name, got, exp);
            errors++;
        end else begin
            $display("  ok   %-22s 0x%08x", name, got);
        end
    endtask

    initial begin
        $dumpfile("program_counter_tb.vcd");
        $dumpvars(0, program_counter_tb);

        // assert reset
        rst_n = 0; pc_load = 0; pc_next = 32'h0;
        @(posedge clk); #1;
        check("after reset", pc, 32'h0000_0000);

        // release reset -> sequential +4 each cycle
        rst_n = 1;
        @(posedge clk); #1;
        check("step 1 (+4)", pc, 32'h0000_0004);
        @(posedge clk); #1;
        check("step 2 (+4)", pc, 32'h0000_0008);

        // a branch/jump: load an explicit target
        pc_load = 1; pc_next = 32'h0000_0100;
        @(posedge clk); #1;
        check("after load target", pc, 32'h0000_0100);

        // resume sequential from the loaded address
        pc_load = 0;
        @(posedge clk); #1;
        check("step after load (+4)", pc, 32'h0000_0104);

        // reset can happen at any time
        rst_n = 0;
        @(posedge clk); #1;
        check("re-reset", pc, 32'h0000_0000);

        if (errors == 0) $display("PROGRAM COUNTER: ALL TESTS PASSED");
        else             $display("PROGRAM COUNTER: %0d FAILURE(S)", errors);
        $finish;
    end

endmodule
