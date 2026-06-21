// =============================================================================
// cycle_counter_tb.sv  --  self-checking spec for the free-running cycle counter
// =============================================================================
// CONTRACT -- cycle_counter(clk, rst_n) -> count
//   * count resets to 0 while rst_n is low
//   * after reset, count increments by 1 on every rising clock edge
// That's the whole module: one 32-bit register. Read it on the bus at CYC_CTR.
// (Sync or async reset both pass this testbench.)
// =============================================================================
`timescale 1ns/1ps

module cycle_counter_tb;
    logic        clk = 0, rst_n;
    logic [31:0] count;

    cycle_counter dut (.clk(clk), .rst_n(rst_n), .count(count));
    always #5 clk = ~clk;            // 100 MHz

    int errors = 0;
    task check(input [31:0] got, exp, input string what);
        if (got !== exp) begin
            $display("FAIL %s: got %0d exp %0d", what, got, exp);
            errors++;
        end
    endtask

    initial begin
        rst_n = 0;
        @(posedge clk); #1; check(count, 0, "reset = 0");
        rst_n = 1;
        repeat (10) @(posedge clk); #1; check(count, 10, "after 10 clks");
        repeat (5)  @(posedge clk); #1; check(count, 15, "after 15 clks");

        if (errors == 0) $display("cycle_counter : ALL TESTS PASSED");
        else             $display("cycle_counter : %0d FAILURES", errors);
        $finish;
    end
endmodule
