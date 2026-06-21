// =============================================================================
// control_unit.sv  --  the instruction decoder (full RV32I base)
// =============================================================================
// opcode (+ funct3, + instr[30]) -> all datapath control signals.
//   reg_write   write rd
//   alu_a_src   ALU operand A: 0=rs1, 1=pc (auipc), 2=zero (lui)
//   alu_b_src   ALU operand B: 0=rs2, 1=imm
//   alu_op      ALU operation (codes from alu.sv)
//   result_src  writeback source: 0=ALU, 1=load data, 2=pc+4 (jal/jalr link)
//   mem_read/mem_write
//   branch      conditional branch (taken decided by branch_unit)
//   jal / jalr  unconditional jumps
//   imm_sel     immediate format for imm_gen: 0=I 1=S 2=B 3=U 4=J
// =============================================================================

module control_unit (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic       funct7_5,     // instruction bit 30
    output logic       reg_write,
    output logic [1:0] alu_a_src,
    output logic       alu_b_src,
    output logic [3:0] alu_op,
    output logic [1:0] result_src,
    output logic       mem_read,
    output logic       mem_write,
    output logic       branch,
    output logic       jal,
    output logic       jalr,
    output logic [2:0] imm_sel
);
    localparam logic [6:0] OP_R     = 7'b0110011, OP_I    = 7'b0010011,
                           OP_LD    = 7'b0000011, OP_ST   = 7'b0100011,
                           OP_BR    = 7'b1100011, OP_LUI  = 7'b0110111,
                           OP_AUIPC = 7'b0010111, OP_JAL  = 7'b1101111,
                           OP_JALR  = 7'b1100111;

    // ALU op for R-type / I-ALU, decoded from funct3 (+funct7_5)
    logic [3:0] alu_funct;
    always_comb begin
        case (funct3)
            3'b000:  alu_funct = (opcode == OP_R && funct7_5) ? 4'd1 : 4'd0; // SUB:ADD
            3'b001:  alu_funct = 4'd5;                                       // SLL
            3'b010:  alu_funct = 4'd8;                                       // SLT
            3'b011:  alu_funct = 4'd9;                                       // SLTU
            3'b100:  alu_funct = 4'd4;                                       // XOR
            3'b101:  alu_funct = funct7_5 ? 4'd7 : 4'd6;                     // SRA:SRL
            3'b110:  alu_funct = 4'd3;                                       // OR
            3'b111:  alu_funct = 4'd2;                                       // AND
            default: alu_funct = 4'd0;
        endcase
    end

    // main decode: default to a safe NOP, then override per opcode
    always_comb begin
        reg_write  = 1'b0;
        alu_a_src  = 2'd0;
        alu_b_src  = 1'b0;
        alu_op     = 4'd0;
        result_src = 2'd0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = 1'b0;
        jal        = 1'b0;
        jalr       = 1'b0;
        imm_sel    = 3'd0;

        case (opcode)
            OP_R:     begin reg_write=1; alu_op=alu_funct;                                 end
            OP_I:     begin reg_write=1; alu_b_src=1; alu_op=alu_funct; imm_sel=3'd0;       end
            OP_LD:    begin reg_write=1; alu_b_src=1; mem_read=1; result_src=2'd1;
                            imm_sel=3'd0;                                                  end
            OP_ST:    begin alu_b_src=1; mem_write=1; imm_sel=3'd1;                         end
            OP_BR:    begin branch=1; imm_sel=3'd2;                                         end
            OP_LUI:   begin reg_write=1; alu_a_src=2'd2; alu_b_src=1; imm_sel=3'd3;         end
            OP_AUIPC: begin reg_write=1; alu_a_src=2'd1; alu_b_src=1; imm_sel=3'd3;         end
            OP_JAL:   begin reg_write=1; result_src=2'd2; jal=1; imm_sel=3'd4;             end
            OP_JALR:  begin reg_write=1; alu_b_src=1; result_src=2'd2; jalr=1; imm_sel=3'd0;end
            default:  ; // fence / unknown -> NOP
        endcase
    end
endmodule
