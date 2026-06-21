// =============================================================================
// register_file_tb.sv  --  WORKED EXAMPLE testbench (study this pattern)
// =============================================================================
// A *self-checking* testbench: it drives inputs, then asserts the outputs are
// what the spec says. At the end it prints PASS or a failure count, so you
// never have to eyeball a waveform to know if the module is correct.
//
// The anatomy of every testbench you'll write:
//   1. Declare signals that connect to the DUT (device under test).
//   2. Instantiate the DUT.
//   3. Generate a clock.
//   4. In an `initial` block: drive inputs, wait for edges, check outputs.
//   5. Dump a .vcd so you *can* open a waveform when something fails.
// =============================================================================
`timescale 1ns/1ps

module register_file_tb;

    // 1. Signals wired to the DUT (names match the module ports so we can
    //    use the `.*` shorthand below).
    logic        clk = 0;
    logic        we;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [31:0] rd_data;
    logic [31:0] rs1_data, rs2_data;

    int errors = 0;

    // 2. Instantiate the DUT. `.*` connects every port to the same-named signal.
    register_file dut (.*);

    // 3. 10 ns clock (toggles every 5 ns).
    always #5 clk = ~clk;

    // ---- helpers --------------------------------------------------------------
    // Write `d` into register `a` on the next rising edge.
    task automatic write_reg(input logic [4:0] a, input logic [31:0] d);
        rd_addr = a; rd_data = d; we = 1;
        @(posedge clk);     // the write takes effect on THIS edge
        #1 we = 0;          // step past the edge, then drop write-enable
    endtask

    // Compare an output against the expected value; record a failure if wrong.
    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got !== exp) begin
            $display("  FAIL %-18s got 0x%08x  expected 0x%08x", name, got, exp);
            errors++;
        end else begin
            $display("  ok   %-18s 0x%08x", name, got);
        end
    endtask

    // 4./5. The test program.
    initial begin
        $dumpfile("register_file_tb.vcd");
        $dumpvars(0, register_file_tb);

        we = 0; rs1_addr = 0; rs2_addr = 0; rd_addr = 0; rd_data = 0;
        @(posedge clk);

        // write/read on port 1
        write_reg(5'd1, 32'hDEAD_BEEF);
        rs1_addr = 5'd1; #1;
        check("x1 readback", rs1_data, 32'hDEAD_BEEF);

        // write/read on port 2
        write_reg(5'd5, 32'd42);
        rs2_addr = 5'd5; #1;
        check("x5 readback", rs2_data, 32'd42);

        // x0 stays zero even after we try to write it
        write_reg(5'd0, 32'hFFFF_FFFF);
        rs1_addr = 5'd0; #1;
        check("x0 stays zero", rs1_data, 32'd0);

        // both ports read independently
        write_reg(5'd7, 32'h0000_1234);
        rs1_addr = 5'd1; rs2_addr = 5'd7; #1;
        check("port1 = x1", rs1_data, 32'hDEAD_BEEF);
        check("port2 = x7", rs2_data, 32'h0000_1234);

        if (errors == 0) $display("REGISTER FILE: ALL TESTS PASSED");
        else             $display("REGISTER FILE: %0d FAILURE(S)", errors);
        $finish;
    end

endmodule
