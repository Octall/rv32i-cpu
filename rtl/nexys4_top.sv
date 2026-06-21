// =============================================================================
// nexys4_top.sv  --  board wrapper: run cpu_top slowly and show it on the LEDs
// =============================================================================
// This is the SYNTHESIS top module (set it as "top" in Vivado, NOT cpu_top).
// It:
//   * divides the 100 MHz board clock down to a few Hz so the CPU is watchable,
//   * runs cpu_top on that slow clock, reset by the red CPU-reset button,
//   * shows either the PC or a watched register on the 16 LEDs (selected by SW0).
//
// Watching a register without adding a port to the register file: we reuse
// cpu_top's debug taps and keep our own latch of the last value written to one
// register -- exactly how the testbench's "shadow" worked.
//
// LED display:
//   SW0 = 0  ->  PC  (watch it step 0,4,8,... then halt at 0x38 on the spin loop)
//   SW0 = 1  ->  the value last written to register WATCH (x11 -> 7)
// =============================================================================

module nexys4_top (
    input  logic        CLK100MHZ,    // 100 MHz board oscillator
    input  logic        CPU_RESETN,   // red reset button (active-LOW)
    input  logic [0:15]  SW,           // SW0 selects what the LEDs show
    input  logic         CLK_BTN,
    output logic [15:0] LED
);
    localparam logic [4:0] WATCH = 5'd11;   // which register to display

    // ---- slow clock for the CPU ----
    logic clk;
    logic cpu_clk;
    logic btn_clk;
    
    clock_divider #(.DIV_BITS(25)) u_div (.clk_in(CLK100MHZ), .clk_out(cpu_clk));
    debounce u_debounce (.clk(clk), .button(CLK_BTN), .debounced(btn_clk));

    // ---- the CPU ----
    logic [31:0] dbg_pc, dbg_result;
    logic        dbg_rw;
    logic [4:0]  dbg_rd;

    cpu_top u_cpu (
        .clk             (clk),
        .rst_n           (CPU_RESETN),
        .debug_pc        (dbg_pc),
        .debug_reg_write (dbg_rw),
        .debug_rd        (dbg_rd),
        .debug_result    (dbg_result)
    );

    // ---- latch the last value written to register WATCH ----
    logic [31:0] watched;
    always_ff @(posedge cpu_clk) begin
        if (!CPU_RESETN)
            watched <= '0;
        else if (dbg_rw && dbg_rd == WATCH)
            watched <= dbg_result;
    end
    
    assign clk = SW[1] ? btn_clk : cpu_clk;

    // ---- drive the LEDs ----
    assign LED = SW[0] ? watched[15:0] : dbg_pc[15:0];
endmodule
