// =============================================================================
// uart_tx_tb.sv  --  self-checking spec for uart_tx (115200-8N1, LSB first)
// =============================================================================
// Bound to YOUR uart_tx ports: #(CLK_HZ, BAUD) (clk, rst_n, start, data, tx, busy).
//
// Robust handshake:
//   * stimulus changes on the NEGEDGE so it never races the DUT's posedge sample
//   * the receiver is FORKED alongside the sender so its @(negedge tx) is armed
//     BEFORE the start bit pulls the line low (otherwise it misses the edge)
//   * an independent oversampler reads each bit at its centre, LSB first
// =============================================================================
`timescale 1ns/1ps

module uart_tx_tb;
    localparam int CLK_HZ = 100_000_000, BAUD = 115_200;
    localparam int CPB    = CLK_HZ / BAUD;        // clocks per bit (868)

    logic       clk = 0, rst_n = 0, start = 0;
    logic [7:0] data;
    logic       tx, busy;

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .data(data), .tx(tx), .busy(busy));
    always #5 clk = ~clk;                          // 100 MHz

    int errors = 0;
    logic [7:0] rx;

    // sender: one-cycle start pulse, driven on negedge to avoid the posedge race
    task automatic send_byte(input [7:0] v);
        @(negedge clk); data = v; start = 1;
        @(negedge clk); start = 0;
    endtask

    // receiver: catch the start edge, then sample each bit centre (LSB first)
    task automatic recv_byte(output [7:0] b);
        @(negedge tx);                             // start bit pulls line low
        repeat (CPB + CPB/2) @(posedge clk);       // land mid data-bit 0
        for (int i = 0; i < 8; i++) begin
            b[i] = tx;
            repeat (CPB) @(posedge clk);
        end
    endtask

    task automatic check_byte(input [7:0] v);
        fork
            send_byte(v);
            recv_byte(rx);
        join
        if (rx !== v) begin
            $display("FAIL: sent %02x got %02x", v, rx);
            errors++;
        end
        wait (!busy); @(negedge clk);              // let the frame finish
    endtask

    // watchdog (full run is ~0.35 ms sim time)
    initial begin
        #2_000_000;
        $display("uart_tx : TIMEOUT (hung) -- errors=%0d", errors);
        $finish;
    end

    initial begin
        repeat (4) @(posedge clk); rst_n = 1; @(negedge clk);
        check_byte(8'h41);   // 'A'
        check_byte(8'h55);   // 0101_0101
        check_byte(8'h00);   // all zeros
        check_byte(8'hFF);   // all ones

        if (errors == 0) $display("uart_tx : ALL TESTS PASSED");
        else             $display("uart_tx : %0d FAILURES", errors);
        $finish;
    end
endmodule
