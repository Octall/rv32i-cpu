// =============================================================================
// data_memory.sv  --  load/store RAM with per-byte write enables
// =============================================================================
// Combinational word read; synchronous write where each byte lane is written
// only if its byte_en bit is set (and mem_write). byte_en + the aligned
// write_data come from store_align. (See docs/rv32i-completion-spec.md §1.5.)
// =============================================================================

module data_memory #(
    parameter int    DEPTH     = 16384,
    // Harvard unified image: data memory must hold the SAME hex as instr_memory
    // (the program's .rodata/.data live here). Sims override this via hierarchical
    // $readmemh; on the board this default (or the PROG_HEX define) loads the BRAM.
    parameter string INIT_FILE = "/home/vr-pc/Documents/mahmoud/riscv-core/programs/prog.hex"
) (
    input  logic        clk,
    input  logic        mem_write,    // 1 = store this cycle
    input  logic [3:0]  byte_en,      // per-byte write enables (from store_align)
    input  logic [31:0] addr,         // byte address (from the ALU)
    input  logic [31:0] write_data,   // aligned store data (from store_align)
    output logic [31:0] read_data     // value loaded (combinational)
);

    logic [31:0] mem [0:DEPTH-1];

    // optional program-image preload (same hex as instr_memory; "" = skip,
    // so the test runner's own $readmemh keeps working unchanged)
    initial begin
`ifdef PROG_HEX
        $readmemh(`PROG_HEX, mem);                  // board program (Vivado verilog_define)
`else
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
`endif
    end

    // synchronous, per-lane write
    always_ff @(posedge clk) begin : write_cycle
        if (mem_write) begin
            if (byte_en[0]) mem[addr[15:2]][7:0]   <= write_data[7:0];
            if (byte_en[1]) mem[addr[15:2]][15:8]  <= write_data[15:8];
            if (byte_en[2]) mem[addr[15:2]][23:16] <= write_data[23:16];
            if (byte_en[3]) mem[addr[15:2]][31:24] <= write_data[31:24];
        end
    end

    // combinational word read
    assign read_data = mem[addr[15:2]];
endmodule
