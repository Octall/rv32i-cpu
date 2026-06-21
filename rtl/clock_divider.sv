// =============================================================================
// clock_divider.sv  --  slow the 100 MHz board clock down so we can SEE the CPU
// =============================================================================
// The Nexys 4 runs at 100 MHz; the CPU would execute the whole program in well
// under a microsecond -- invisible. This counter divides the clock down: a free-
// running counter's top bit toggles every 2^(DIV_BITS-1) input cycles, giving a
// much slower square wave to clock the CPU with.
//
//   output frequency = 100 MHz / 2^DIV_BITS
//   DIV_BITS = 25  ->  100e6 / 2^25  ~= 3 Hz   (about 1 instruction every 0.3 s)
//
// NOTE: feeding a logic-generated signal as a clock is fine for a slow demo, but
// it's not best practice (the "proper" way is a clock-enable pulse + BUFG). Good
// enough to watch the CPU run on LEDs; Vivado may emit timing warnings you can
// ignore for this demo.
// =============================================================================

module clock_divider #(
    parameter int DIV_BITS = 25
) (
    input  logic clk_in,
    output logic clk_out
);
    logic [DIV_BITS-1:0] count = '0;

    always_ff @(posedge clk_in)
        count <= count + 1'b1;

    assign clk_out = count[DIV_BITS-1];   // MSB = slowest bit
endmodule
