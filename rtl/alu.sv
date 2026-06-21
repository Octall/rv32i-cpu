// =============================================================================
// alu.sv  --  YOUR TASK: the arithmetic / logic unit
// =============================================================================
// Computes  result = a <op> b,  where alu_op selects the operation:
//
//     0 ADD    1 SUB    2 AND    3 OR     4 XOR
//     5 SLL    6 SRL    7 SRA    8 SLT    9 SLTU
//
// Also drives  zero = (result == 0)  -- a branch instruction (beq) will use it.
//
// New SystemVerilog ideas you'll need here:
//   * Signed vs unsigned. By default `<`, `>`, and `>>` treat values as
//     UNSIGNED. For the signed operations, wrap operands in $signed():
//         SLT (signed less-than):        $signed(a) <  $signed(b)
//         SRA (arithmetic shift right):  $signed(a) >>> shamt
//     SLTU and SRL stay unsigned:        a < b   and   a >> shamt
//   * Shift amount is only the low 5 bits of b (a 32-bit value can shift by
//     0..31). Use b[4:0]. The testbench shifts by 32 to check you mask it.
//   * SLT/SLTU yield a 32-bit value that is 0 or 1, e.g.
//         result = {31'b0, (some_condition)};   // or  (cond) ? 32'd1 : 32'd0
//
// HINTS:
//   * Structure: always_comb + case(alu_op), one arm per op, plus a default.
//   * `zero` is pure combinational -- an `assign` outside the case.
//
// Goal: make `make sim TB=alu` print ALL TESTS PASSED.
// =============================================================================

module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_op,
    output logic [31:0] result,
    output logic        zero        // 1 when result == 0
);

    always_comb begin : alu_logic
        case (alu_op)
            4'd0: // ADD
                result = a + b;
            4'd1: 
                result = a - b;
            4'd2:
                result = a & b;
            4'd3:
                result = a | b;
            4'd4:
                result = a ^ b;
            4'd5:
                result = a << b[4:0];
            4'd6:
                result = a >> b[4:0];
            4'd7:
                result = $signed(a) >>> b[4:0];
            4'd8:
                result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            4'd9:
                result = (a < b) ? 32'd1 : 32'd0;
            default: 
                result = 0;
        endcase

    end
    
    assign zero = (result != 32'd0) ? 1'b0 : 1'b1;

endmodule   
