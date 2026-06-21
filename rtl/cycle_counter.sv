module cycle_counter (
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) count <= '0;
        else count <= count + 1;
    end
endmodule