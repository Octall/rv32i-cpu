// =============================================================================
// alu_tb.sv  --  the SPEC for the ALU. Do NOT edit this.
// =============================================================================
// Run with:  make sim TB=alu
// Each vector checks `result`; it also checks `zero` == (result == 0).
// =============================================================================
`timescale 1ns/1ps

module alu_tb;

    logic [31:0] a, b;
    logic [3:0]  alu_op;
    logic [31:0] result;
    logic        zero;

    int errors = 0;

    localparam logic [3:0] OP_ADD = 4'd0, OP_SUB  = 4'd1, OP_AND = 4'd2,
                           OP_OR  = 4'd3, OP_XOR  = 4'd4, OP_SLL = 4'd5,
                           OP_SRL = 4'd6, OP_SRA  = 4'd7, OP_SLT = 4'd8,
                           OP_SLTU = 4'd9;

    alu dut (.*);

    // Drive inputs, then check both result and the zero flag.
    task automatic check(input string name, input logic [3:0] op,
                         input logic [31:0] aa, input logic [31:0] bb,
                         input logic [31:0] exp);
        a = aa; b = bb; alu_op = op; #1;
        if (result !== exp) begin
            $display("  FAIL %-10s result 0x%08x  expected 0x%08x", name, result, exp);
            errors++;
        end else if (zero !== (exp == 32'd0)) begin
            $display("  FAIL %-10s zero=%0b  expected %0b", name, zero, (exp == 32'd0));
            errors++;
        end else begin
            $display("  ok   %-10s 0x%08x  zero=%0b", name, result, zero);
        end
    endtask

    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);

        check("ADD",       OP_ADD,  32'h00000005, 32'h00000003, 32'h00000008);
        check("SUB",       OP_SUB,  32'h00000005, 32'h00000003, 32'h00000002);
        check("SUB->0",    OP_SUB,  32'h00000007, 32'h00000007, 32'h00000000);
        check("AND",       OP_AND,  32'hFF00FF00, 32'h0F0F0F0F, 32'h0F000F00);
        check("OR",        OP_OR,   32'hFF00FF00, 32'h0F0F0F0F, 32'hFF0FFF0F);
        check("XOR",       OP_XOR,  32'hFF00FF00, 32'h0F0F0F0F, 32'hF00FF00F);
        check("SLL",       OP_SLL,  32'h00000001, 32'h00000004, 32'h00000010);
        check("SLL shamt", OP_SLL,  32'h00000001, 32'h00000020, 32'h00000001);
        check("SRL",       OP_SRL,  32'h80000000, 32'h00000004, 32'h08000000);
        check("SRA",       OP_SRA,  32'h80000000, 32'h00000004, 32'hF8000000);
        check("SLT s<",    OP_SLT,  32'hFFFFFFFB, 32'h00000003, 32'h00000001);
        check("SLT s!<",   OP_SLT,  32'h00000005, 32'hFFFFFFFB, 32'h00000000);
        check("SLTU u<",   OP_SLTU, 32'h00000005, 32'hFFFFFFFF, 32'h00000001);
        check("SLTU u!<",  OP_SLTU, 32'hFFFFFFFF, 32'h00000005, 32'h00000000);

        if (errors == 0) $display("ALU: ALL TESTS PASSED");
        else             $display("ALU: %0d FAILURE(S)", errors);
        $finish;
    end

endmodule
