// load_extend_tb.sv -- byte/half select + sign/zero extension. word = 0x0080FF7F.
`timescale 1ns/1ps
module load_extend_tb;
    logic [2:0]  funct3;
    logic [1:0]  addr_lo;
    logic [31:0] word, result;
    int errors = 0;

    load_extend dut (.*);

    task automatic chk(input string n, input logic [2:0] f3, input logic [1:0] al,
                       input logic [31:0] exp);
        word = 32'h0080FF7F; funct3=f3; addr_lo=al; #1;
        if (result !== exp) begin
            $display("  FAIL %-9s got %08x expected %08x", n, result, exp); errors++;
        end else $display("  ok   %-9s %08x", n, result);
    endtask

    initial begin
        $dumpfile("load_extend_tb.vcd"); $dumpvars(0, load_extend_tb);
        chk("lw",       3'b010, 2'd0, 32'h0080FF7F);
        chk("lb a0(+)", 3'b000, 2'd0, 32'h0000007F);
        chk("lb a1(-)", 3'b000, 2'd1, 32'hFFFFFFFF);
        chk("lb a2(-)", 3'b000, 2'd2, 32'hFFFFFF80);
        chk("lb a3(+)", 3'b000, 2'd3, 32'h00000000);
        chk("lbu a1",   3'b100, 2'd1, 32'h000000FF);
        chk("lh a0(-)", 3'b001, 2'd0, 32'hFFFFFF7F);
        chk("lh a2(+)", 3'b001, 2'd2, 32'h00000080);
        chk("lhu a0",   3'b101, 2'd0, 32'h0000FF7F);
        chk("lhu a2",   3'b101, 2'd2, 32'h00000080);
        if (errors==0) $display("LOAD EXTEND: ALL TESTS PASSED");
        else           $display("LOAD EXTEND: %0d FAILURE(S)", errors);
        $finish;
    end
endmodule
