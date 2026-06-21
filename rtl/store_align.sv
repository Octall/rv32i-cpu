// =============================================================================
// store_align.sv  --  position store data + compute byte write-enables
// =============================================================================
// Given the store width (funct3) and the low address bits, produce:
//   wdata   - rs2_data replicated across lanes so the right bytes sit in place
//   byte_en - which of the 4 byte lanes data_memory should actually write
// (See docs/rv32i-completion-spec.md §1.5.)
// =============================================================================

module store_align (
    input  logic [2:0]  funct3,     // sb=000, sh=001, sw=010
    input  logic [1:0]  addr_lo,    // address[1:0]
    input  logic [31:0] rs2_data,   // value to store
    output logic [31:0] wdata,      // aligned data for data_memory
    output logic [3:0]  byte_en     // per-byte write enables
);
    always_comb begin
        wdata   = rs2_data;
        byte_en = 4'b0000;
        case (funct3)
            3'b000: begin                       // sb
                wdata   = {4{rs2_data[7:0]}};
                byte_en = 4'b0001 << addr_lo;
            end
            3'b001: begin                       // sh
                wdata   = {2{rs2_data[15:0]}};
                byte_en = addr_lo[1] ? 4'b1100 : 4'b0011;
            end
            3'b010: begin                       // sw
                wdata   = rs2_data;
                byte_en = 4'b1111;
            end
            default: byte_en = 4'b0000;         // no write
        endcase
    end
endmodule
