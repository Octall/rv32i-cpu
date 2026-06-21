// =============================================================================
// branch_unit.sv  --  decides whether a conditional branch is taken (by funct3)
// =============================================================================
module branch_unit (
    input  logic [2:0]  funct3,
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,
    output logic        taken
);
    always_comb begin
        case (funct3)
            3'b000:  taken = (rs1_data == rs2_data);                   // beq
            3'b001:  taken = (rs1_data != rs2_data);                   // bne
            3'b100:  taken = ($signed(rs1_data) <  $signed(rs2_data)); // blt
            3'b101:  taken = ($signed(rs1_data) >= $signed(rs2_data)); // bge
            3'b110:  taken = (rs1_data <  rs2_data);                   // bltu
            3'b111:  taken = (rs1_data >= rs2_data);                   // bgeu
            default: taken = 1'b0;
        endcase
    end
endmodule
