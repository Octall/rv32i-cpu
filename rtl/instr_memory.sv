// =============================================================================
// instr_memory.sv  --  YOUR TASK: the instruction ROM
// =============================================================================
// Holds the program. The CPU gives it a byte address (the PC) and it returns
// the 32-bit instruction stored there.
//
// Key idea -- the read is COMBINATIONAL (no clock):
//   In a single-cycle CPU the instruction has to come back in the *same* cycle
//   the PC points at it, so this works like register_file's read ports
//   (an `assign`), NOT like an always_ff.
//
// Byte address vs word index:
//   RV32 instructions are 4 bytes wide and word-aligned, so they live at byte
//   addresses 0, 4, 8, 12, ...  Internally the memory is an array of 32-bit
//   *words*, so the word index is the byte address / 4 -- i.e. drop the bottom
//   2 bits of `addr`.
//
// Loading the program:
//   $readmemh reads a text file of 8-hex-digit words (one per line) into the
//   array. The file name comes in via the INIT_FILE parameter.
//
// Goal: make `make sim TB=instr_memory` print ALL TESTS PASSED.
//
// HINTS (enough to do it -- no full solution):
//   * Storage:   logic [31:0] mem [0:DEPTH-1];
//   * Load it:   initial $readmemh(INIT_FILE, mem);    // an initial block
//   * Word index from the byte address: addr[?:2]. DEPTH=256 needs 8 index
//     bits, so the slice is addr[9:2].
//   * Drive the output with a combinational `assign` from mem[word_index].
// =============================================================================

module instr_memory #(
    parameter int    DEPTH     = 16384,
    parameter string INIT_FILE = "/home/vr-pc/Documents/mahmoud/riscv-core/programs/prog.hex"
) (
    input  logic [31:0] addr,    // byte address (comes from the PC)
    output logic [31:0] instr    // 32-bit instruction stored at that address
);

    // Loading memory in from file
    logic [31:0] mem [0:DEPTH-1];
    initial begin
`ifdef PROG_HEX
        $readmemh(`PROG_HEX, mem);                  // board program (Vivado verilog_define)
`else
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
`endif
    end

    assign instr = mem[addr[15:2]];   // 16384 words -> 14 index bits
    
endmodule
