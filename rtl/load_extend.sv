// =============================================================================
// load_extend.sv  --  select + sign/zero-extend a loaded byte/half/word
// =============================================================================
// data_memory returns the full 32-bit word; this picks the addressed byte/half
// and extends it to 32 bits per the load width (funct3).
// (See docs/rv32i-completion-spec.md §1.5.)
// =============================================================================

module load_extend (
    input  logic [2:0]  funct3,    // lb=000, lh=001, lw=010, lbu=100, lhu=101
    input  logic [1:0]  addr_lo,   // address[1:0]
    input  logic [31:0] word,      // word read from data_memory
    output logic [31:0] result
);
    logic [7:0]  b;
    logic [15:0] h;

    always_comb begin
        b = word[addr_lo*8 +: 8];                 // byte selected by addr_lo
        h = addr_lo[1] ? word[31:16] : word[15:0];// half selected by addr_lo[1]
        case (funct3)
            3'b000:  result = {{24{b[7]}},  b};    // lb  (sign-extend)
            3'b001:  result = {{16{h[15]}}, h};    // lh  (sign-extend)
            3'b010:  result = word;                // lw
            3'b100:  result = {24'b0, b};          // lbu (zero-extend)
            3'b101:  result = {16'b0, h};          // lhu (zero-extend)
            default: result = word;
        endcase
    end
endmodule
