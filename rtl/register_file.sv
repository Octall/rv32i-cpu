// =============================================================================
// register_file.sv  --  WORKED EXAMPLE (study this, then copy the pattern)
// =============================================================================
// The RV32I register file: 32 general-purpose registers, each 32 bits.
//   - Register x0 is hardwired to zero (reads 0, writes are ignored).
//   - Two combinational ("asynchronous") read ports  -> rs1, rs2.
//   - One synchronous write port (updates on the rising clock edge).
//
// This is the simplest piece of CPU *state*. Read it top to bottom and notice:
//   1. Ports are declared with direction + type + width.
//   2. State lives in `regs` (an unpacked array of 32 words).
//   3. Writes are sequential (always_ff @posedge) -- they happen on a clock edge.
//   4. Reads are combinational (assign) -- they update the instant the address
//      changes, with no clock involved. A real CPU needs the operands *now*.
// =============================================================================

module register_file (
    input  logic        clk,        // clock
    input  logic        we,         // write enable
    input  logic [4:0]  rs1_addr,   // read-port-1 register number (0..31)
    input  logic [4:0]  rs2_addr,   // read-port-2 register number (0..31)
    input  logic [4:0]  rd_addr,    // write register number (0..31)
    input  logic [31:0] rd_data,    // data to write
    output logic [31:0] rs1_data,   // read-port-1 data out
    output logic [31:0] rs2_data    // read-port-2 data out
);

    // 32 registers x 32 bits. (regs[0] exists but we never read/write it --
    // the x0 = 0 rule is enforced below, which is cheaper than special-casing
    // storage.)
    logic [31:0] regs [0:31];

    // ---- Write port: synchronous, ignores writes to x0 -----------------------
    always_ff @(posedge clk) begin
        if (we && (rd_addr != 5'd0))
            regs[rd_addr] <= rd_data;
    end

    // ---- Read ports: combinational, x0 always reads as 0 ----------------------
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];

endmodule
