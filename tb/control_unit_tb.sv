// =============================================================================
// control_unit_tb.sv  --  spec for the full-RV32I decoder. Do NOT edit.
// =============================================================================
`timescale 1ns/1ps

module control_unit_tb;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic       funct7_5;
    logic       reg_write, alu_b_src, mem_read, mem_write, branch, jal, jalr;
    logic [1:0] alu_a_src, result_src;
    logic [3:0] alu_op;
    logic [2:0] imm_sel;

    int errors = 0;

    localparam logic [6:0] OP_R=7'b0110011, OP_I=7'b0010011, OP_LD=7'b0000011,
                           OP_ST=7'b0100011, OP_BR=7'b1100011, OP_LUI=7'b0110111,
                           OP_AUIPC=7'b0010111, OP_JAL=7'b1101111, OP_JALR=7'b1100111;

    control_unit dut (.*);

    task automatic chk(input string name,
        input logic [6:0] op, input logic [2:0] f3, input logic f7,
        input logic e_rw, input logic [1:0] e_aa, input logic e_ab,
        input logic [3:0] e_aluop, input logic [1:0] e_rs,
        input logic e_mr, input logic e_mw, input logic e_br,
        input logic e_jal, input logic e_jalr, input logic [2:0] e_imm);
        opcode=op; funct3=f3; funct7_5=f7; #1;
        if (reg_write!==e_rw || alu_a_src!==e_aa || alu_b_src!==e_ab || alu_op!==e_aluop ||
            result_src!==e_rs || mem_read!==e_mr || mem_write!==e_mw || branch!==e_br ||
            jal!==e_jal || jalr!==e_jalr || imm_sel!==e_imm) begin
            $display("  FAIL %s", name);
            $display("    got rw=%b aa=%0d ab=%b alu=%0d rs=%0d mr=%b mw=%b br=%b jal=%b jalr=%b imm=%0d",
                reg_write,alu_a_src,alu_b_src,alu_op,result_src,mem_read,mem_write,branch,jal,jalr,imm_sel);
            $display("    exp rw=%b aa=%0d ab=%b alu=%0d rs=%0d mr=%b mw=%b br=%b jal=%b jalr=%b imm=%0d",
                e_rw,e_aa,e_ab,e_aluop,e_rs,e_mr,e_mw,e_br,e_jal,e_jalr,e_imm);
            errors++;
        end else $display("  ok   %s", name);
    endtask

    initial begin
        $dumpfile("control_unit_tb.vcd"); $dumpvars(0, control_unit_tb);
        //                  op        f3      f7  rw aa ab alu rs mr mw br jal jalr imm
        chk("R  add",  OP_R,    3'b000, 1'b0,  1, 0, 0, 0,  0, 0, 0, 0, 0,  0,  0);
        chk("R  sub",  OP_R,    3'b000, 1'b1,  1, 0, 0, 1,  0, 0, 0, 0, 0,  0,  0);
        chk("R  and",  OP_R,    3'b111, 1'b0,  1, 0, 0, 2,  0, 0, 0, 0, 0,  0,  0);
        chk("I  addi", OP_I,    3'b000, 1'b0,  1, 0, 1, 0,  0, 0, 0, 0, 0,  0,  0);
        chk("I  srai", OP_I,    3'b101, 1'b1,  1, 0, 1, 7,  0, 0, 0, 0, 0,  0,  0);
        chk("lw",      OP_LD,   3'b010, 1'b0,  1, 0, 1, 0,  1, 1, 0, 0, 0,  0,  0);
        chk("sw",      OP_ST,   3'b010, 1'b0,  0, 0, 1, 0,  0, 0, 1, 0, 0,  0,  1);
        chk("beq",     OP_BR,   3'b000, 1'b0,  0, 0, 0, 0,  0, 0, 0, 1, 0,  0,  2);
        chk("lui",     OP_LUI,  3'b000, 1'b0,  1, 2, 1, 0,  0, 0, 0, 0, 0,  0,  3);
        chk("auipc",   OP_AUIPC,3'b000, 1'b0,  1, 1, 1, 0,  0, 0, 0, 0, 0,  0,  3);
        chk("jal",     OP_JAL,  3'b000, 1'b0,  1, 0, 0, 0,  2, 0, 0, 0, 1,  0,  4);
        chk("jalr",    OP_JALR, 3'b000, 1'b0,  1, 0, 1, 0,  2, 0, 0, 0, 0,  1,  0);
        chk("unknown", 7'h7F,   3'b000, 1'b0,  0, 0, 0, 0,  0, 0, 0, 0, 0,  0,  0);

        if (errors==0) $display("CONTROL UNIT: ALL TESTS PASSED");
        else           $display("CONTROL UNIT: %0d FAILURE(S)", errors);
        $finish;
    end
endmodule
