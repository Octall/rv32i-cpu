// =============================================================================
// imm_gen.sv  --  YOUR TASK: the immediate generator
// =============================================================================
// Many instructions carry a constant ("immediate") encoded in their bits.
// The catch: RISC-V scatters those bits around differently per instruction
// FORMAT, to keep register fields in fixed positions. This module reassembles
// the immediate and SIGN-EXTENDS it to 32 bits.
//
// `imm_sel` tells you which format to use (the control unit will drive this in
// the full CPU; here the testbench drives it directly):
//     0 = I    1 = S    2 = B    3 = U    4 = J
//
// RV32I immediate layouts (the spec you're implementing -- each line says which
// instruction bits supply which immediate bits; everything above the listed
// top bit is filled by SIGN EXTENSION):
//
//
// Goal: make `make sim TB=imm_gen` print ALL TESTS PASSED.
//
// HINTS:
//   * Use `always_comb` with a `case (imm_sel)` (this is combinational -- the
//     immediate is just a function of the current instruction).
//   * Build each immediate by CONCATENATING bit fields with `{ ... }`.
//     Example concatenation syntax:  {instr[31:25], instr[11:7]}
//   * SIGN-EXTEND by REPLICATING the top bit. To extend a 12-bit value whose
//     sign bit is instr[31] up to 32 bits:   {{20{instr[31]}}, <the 12 bits>}
//     ({{N{x}}} makes N copies of x.) Work out N for each format.
//   * The trailing `imm[0] = 0` in B and J just means concatenate a `1'b0` (or
//     leave bit 0 unconnected and start at imm[1]).
// =============================================================================

module imm_gen (
    input  logic [31:0] instr,
    input  logic [2:0]  imm_sel,   // 0=I 1=S 2=B 3=U 4=J
    output logic [31:0] imm
);

    always_comb begin : imm_comb
        case (imm_sel)
            3'd0: // I
                imm = {{20{instr[31]}}, instr[31:20]};
            3'd1: // S
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            3'd2: // B
                imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            3'd3: // U
                imm = {instr[31:12], 12'b0};
            3'd4:
                imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            default: 
                imm = 0;
        endcase
    end
endmodule

//   I:  imm[11:0]  = instr[31:20]
//   S:  imm[11:5]  = instr[31:25],  imm[4:0]  = instr[11:7]
//   B:  imm[12]    = instr[31],     imm[11]   = instr[7],
//       imm[10:5]  = instr[30:25],  imm[4:1]  = instr[11:8],  imm[0] = 0
//   U:  imm[31:12] = instr[31:12],  imm[11:0] = 0            (no sign-extend)
//   J:  imm[20]    = instr[31],     imm[19:12]= instr[19:12],
//       imm[11]    = instr[20],     imm[10:1] = instr[30:21], imm[0] = 0