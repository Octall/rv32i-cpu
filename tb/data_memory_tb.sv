// data_memory_tb.sv -- byte-enabled writes. Do NOT edit.
`timescale 1ns/1ps
module data_memory_tb;
    logic        clk = 0, mem_write;
    logic [3:0]  byte_en;
    logic [31:0] addr, write_data, read_data;
    int errors = 0;

    data_memory #(.DEPTH(256)) dut (.*);
    always #5 clk = ~clk;

    task automatic wr(input logic [31:0] a, input logic [3:0] be, input logic [31:0] d);
        addr=a; byte_en=be; write_data=d; mem_write=1;
        @(posedge clk); #1 mem_write=0;
    endtask

    task automatic chk(input string n, input logic [31:0] a, input logic [31:0] e);
        addr=a; #1;
        if (read_data !== e) begin
            $display("  FAIL %-12s got %08x expected %08x", n, read_data, e); errors++;
        end else $display("  ok   %-12s %08x", n, read_data);
    endtask

    initial begin
        $dumpfile("data_memory_tb.vcd"); $dumpvars(0, data_memory_tb);
        mem_write=0; byte_en=0; addr=0; write_data=0;
        @(posedge clk);

        wr(0, 4'b1111, 32'h11223344);  chk("full word",  0, 32'h11223344);
        wr(0, 4'b0001, 32'hAABBCCDD);  chk("byte0 only",  0, 32'h112233DD); // only lane0 -> DD
        wr(0, 4'b1100, 32'h99887766);  chk("bytes 2,3",   0, 32'h998833DD); // lanes 3,2 -> 99,88

        // mem_write low: nothing changes
        addr=0; byte_en=4'b1111; write_data=32'h00000000; mem_write=0;
        @(posedge clk); #1;
        chk("no-write",    0, 32'h998833DD);

        wr(4, 4'b1111, 32'hCAFEF00D);  chk("word @4",     4, 32'hCAFEF00D);
        chk("@0 intact",   0, 32'h998833DD);

        if (errors==0) $display("DATA MEMORY: ALL TESTS PASSED");
        else           $display("DATA MEMORY: %0d FAILURE(S)", errors);
        $finish;
    end
endmodule
