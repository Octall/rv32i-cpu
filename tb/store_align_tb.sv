// store_align_tb.sv -- checks byte_en exactly, and the data in ENABLED lanes.
`timescale 1ns/1ps
module store_align_tb;
    logic [2:0]  funct3;
    logic [1:0]  addr_lo;
    logic [31:0] rs2_data, wdata;
    logic [3:0]  byte_en;
    int errors = 0;

    store_align dut (.*);

    // expand a 4-bit byte-enable into a 32-bit lane mask (0xFF per enabled byte)
    function automatic logic [31:0] lanemask(input logic [3:0] be);
        lanemask = {{8{be[3]}}, {8{be[2]}}, {8{be[1]}}, {8{be[0]}}};
    endfunction

    task automatic chk(input string n, input logic [2:0] f3, input logic [1:0] al,
                       input logic [31:0] rs2, input logic [3:0] ebe, input logic [31:0] eword);
        funct3=f3; addr_lo=al; rs2_data=rs2; #1;
        if (byte_en !== ebe) begin
            $display("  FAIL %-8s byte_en=%b expected %b", n, byte_en, ebe); errors++;
        end else if ((wdata & lanemask(ebe)) !== (eword & lanemask(ebe))) begin
            $display("  FAIL %-8s enabled wdata=%08x expected %08x", n,
                     wdata & lanemask(ebe), eword & lanemask(ebe)); errors++;
        end else $display("  ok   %-8s be=%b wdata=%08x", n, byte_en, wdata);
    endtask

    initial begin
        $dumpfile("store_align_tb.vcd"); $dumpvars(0, store_align_tb);
        chk("sw",    3'b010, 2'd0, 32'h12345678, 4'b1111, 32'h12345678);
        chk("sh lo", 3'b001, 2'd0, 32'hDEADBEEF, 4'b0011, 32'h0000BEEF);
        chk("sh hi", 3'b001, 2'd2, 32'hDEADBEEF, 4'b1100, 32'hBEEF0000);
        chk("sb 0",  3'b000, 2'd0, 32'h000000AB, 4'b0001, 32'h000000AB);
        chk("sb 1",  3'b000, 2'd1, 32'h000000AB, 4'b0010, 32'h0000AB00);
        chk("sb 2",  3'b000, 2'd2, 32'h000000AB, 4'b0100, 32'h00AB0000);
        chk("sb 3",  3'b000, 2'd3, 32'h000000AB, 4'b1000, 32'hAB000000);
        if (errors==0) $display("STORE ALIGN: ALL TESTS PASSED");
        else           $display("STORE ALIGN: %0d FAILURE(S)", errors);
        $finish;
    end
endmodule
