module uart_tx #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD   = 115_200 
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic [7:0] data,
    output logic       tx,
    output logic       busy
);
    localparam int DIV = CLK_HZ / BAUD;
    localparam int CW  = $clog2(DIV);

    logic [CW-1:0] baud_count;
    logic [3:0]    bit_idx;
    logic [9:0]    shift_reg;

    assign tx = busy ? shift_reg[0] : 1'b1;

    always_ff @( posedge clk or negedge rst_n ) begin : uart_tx_sync
        if(!rst_n) begin // reset state with cpu reset
            busy <= 1'b0;
            baud_count <= '0;
            bit_idx <= '0;
            shift_reg <= '1;
        end else if (!busy) begin
            if (start) begin
                shift_reg = {1'b1, data, 1'b0}; // stop, data, start (LSB <=> MSB)
                busy <= 1'b1;
                baud_count <= '0;
                bit_idx <= '0;
            end
        end else begin
            if (baud_count == DIV-1) begin // time to send bit
                baud_count <= '0;
                shift_reg <= {1'b1, shift_reg[9:1]}; // shift out LSB (being tx'd by assignment earlier)
                if (bit_idx == 4'd9) busy <= 1'b0;   // once bit index reaches d9, byte tx done, available for next tx
                bit_idx <= bit_idx + 1;
            end else
                baud_count <= baud_count + 1;
        end
    end
endmodule