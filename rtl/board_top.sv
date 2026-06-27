// =============================================================================
// board_top.sv  --  Nexys 4 synthesis top for hardware bring-up
// =============================================================================
// Runs the core on a safe, logic-divided clock and streams its UART output to
// the host PC over the board's USB-UART bridge. Set this as the Vivado top
// (NOT cpu_top, and NOT the old nexys4_top which needs a missing debounce).
//
//   * 100 MHz / 2^3 = 12.5 MHz core clock. The single-cycle core has a long
//     combinational path (fetch->decode->regfile->ALU->dmem->writeback) and
//     will not close timing near 100 MHz, so we clock it slowly. The UART's
//     baud divisor is computed from CLK_HZ, so it tracks this clock.
//   * The program comes from programs/prog.hex, baked into BOTH Harvard memories
//     by the PROG_HEX `define set in build_board.tcl. Build it with: bench/cc.sh -o prog
//   * LEDs show the PC stepping (a visible "it's running" heartbeat) with the
//     halt flag on LD15.
// =============================================================================

module board_top (
    input  logic        CLK100MHZ,    // 100 MHz oscillator   (pin E3)
    input  logic        CPU_RESETN,   // red reset button, active-low (pin C12)
    output logic        UART_RXD_OUT, // FPGA -> host serial TX (pin D4)
    output logic [15:0] LED
);
    localparam int CORE_HZ = 12_500_000;         // 100 MHz / 2^3 = 12.5 MHz

    logic cpu_clk;
    clock_divider #(.DIV_BITS(3)) u_div (.clk_in(CLK100MHZ), .clk_out(cpu_clk));

    logic [31:0] dbg_pc, dbg_res;
    logic        dbg_rw;
    logic [4:0]  dbg_rd;
    logic        uart_tx, halt;

    cpu_top #(.CLK_HZ(CORE_HZ)) u_cpu (
        .clk(cpu_clk), .rst_n(CPU_RESETN),
        .debug_pc(dbg_pc), .debug_reg_write(dbg_rw),
        .debug_rd(dbg_rd), .debug_result(dbg_res),
        .uart_tx(uart_tx), .halt(halt)
    );

    assign UART_RXD_OUT = uart_tx;              // idle-high serial line to the FTDI bridge
    assign LED = {halt, dbg_pc[14:0]};          // heartbeat + halt on LD15
endmodule
