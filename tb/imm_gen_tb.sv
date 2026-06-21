// =============================================================================
// imm_gen_tb.sv  --  the SPEC for the immediate generator. Do NOT edit this.
// =============================================================================
// Run with:  make sim TB=imm_gen
// Each vector is a real RV32I instruction; the expected immediates were
// computed from the RISC-V spec.
// =============================================================================
`timescale 1ns/1ps

module imm_gen_tb;

    logic [31:0] instr;
    logic [2:0]  imm_sel;
    logic [31:0] imm;

    int errors = 0;

    // must match the encoding documented in imm_gen.sv
    localparam logic [2:0] SEL_I = 3'd0,
                           SEL_S = 3'd1,
                           SEL_B = 3'd2,
                           SEL_U = 3'd3,
                           SEL_J = 3'd4;

    imm_gen dut (.*);

    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got !== exp) begin
            $display("  FAIL %-14s got 0x%08x  expected 0x%08x", name, got, exp);
            errors++;
        end else begin
            $display("  ok   %-14s 0x%08x", name, got);
        end
    endtask

    initial begin
        $dumpfile("imm_gen_tb.vcd");
        $dumpvars(0, imm_gen_tb);

        // addi x1, x0, -4      (I-type, negative -> sign-extends)
        instr = 32'hFFC00093; imm_sel = SEL_I; #1;
        check("I-type (-4)",  imm, 32'hFFFFFFFC);

        // sw x5, -8(x1)        (S-type, negative)
        instr = 32'hFE50AC23; imm_sel = SEL_S; #1;
        check("S-type (-8)",  imm, 32'hFFFFFFF8);

        // beq x0, x0, +16      (B-type, positive)
        instr = 32'h00000863; imm_sel = SEL_B; #1;
        check("B-type (+16)", imm, 32'h00000010);

        // lui x5, 0x12345      (U-type)
        instr = 32'h123452B7; imm_sel = SEL_U; #1;
        check("U-type",       imm, 32'h12345000);

        // jal x0, +4           (J-type, positive)
        instr = 32'h0040006F; imm_sel = SEL_J; #1;
        check("J-type (+4)",  imm, 32'h00000004);

        if (errors == 0) $display("IMM GEN: ALL TESTS PASSED");
        else             $display("IMM GEN: %0d FAILURE(S)", errors);
        $finish;
    end

endmodule
