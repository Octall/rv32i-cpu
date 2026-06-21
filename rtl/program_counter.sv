// =============================================================================
// program_counter.sv  --  YOUR FIRST TASK (implement this yourself)
// =============================================================================
// The program counter (PC) holds the address of the instruction currently
// being executed. Every clock cycle it either:
//   * advances to the next instruction  (pc + 4, because RV32 instructions are
//     4 bytes wide), or
//   * jumps to a target address          (when pc_load = 1, e.g. a branch/jump).
//
// The reset puts execution back at address 0.
//
// The testbench in tb/program_counter_tb.sv is the SPEC. Your job is to make
// `make sim TB=program_counter` print "ALL TESTS PASSED". Don't change the
// testbench -- change this module.
//
// Behaviour the testbench expects (synchronous: everything happens on @posedge):
//   - if rst_n == 0   ->  pc becomes 0
//   - else if pc_load ->  pc becomes pc_next
//   - else            ->  pc becomes pc + 4
//
// HINTS (no peeking at a solution -- these are enough):
//   * State that changes on a clock edge lives in an `always_ff @(posedge clk)`
//     block, using non-blocking assignment `<=`.
//   * `rst_n` is active-LOW: reset is happening when it is 0.
//   * Look at how register_file.sv structures its sequential block.
// =============================================================================

module program_counter (
    input  logic        clk,
    input  logic        rst_n,      // active-low synchronous reset
    input  logic        pc_load,    // 1 = load pc_next (branch/jump); 0 = pc+4
    input  logic [31:0] pc_next,    // target address used when pc_load = 1
    output logic [31:0] pc          // current program counter
);

    always_ff @(posedge clk) begin
        if (rst_n == 1'b0)
            pc <= 0;
        else if (pc_load == 1'b1)
            pc <= pc_next;
        else
            pc <= pc + 4;
    end

endmodule
