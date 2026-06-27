// =============================================================================
// cpu_top.sv  --  single-cycle RV32I core (full base ISA)
// =============================================================================
// Wires the datapath: PC -> instr_memory -> decode -> regfile/imm -> ALU ->
// data_memory(load/store) -> writeback, plus branch/jump next-PC logic.
// =============================================================================

module cpu_top #(
    parameter int    CLK_HZ    = 100_000_000    // core clock Hz; sets the UART baud divisor
    // (board program is loaded into the memories via the PROG_HEX `define, not a param --
    //  Icarus can't thread string params, and synthesis needs a compile-time path anyway)
) (
    input  logic        clk,
    input  logic        rst_n,
    // debug taps (read by the testbench)
    output logic [31:0] debug_pc,
    output logic        debug_reg_write,
    output logic [4:0]  debug_rd,
    output logic [31:0] debug_result,
    // memory-mapped I/O (added Phase 0)
    output logic        uart_tx,    // serial line out (idle high)
    output logic        halt        // store to HALT reg -> stop (sim $finish)
);
    // ---- wires ----
    logic [31:0] pc, instr;
    logic [6:0]  opcode;
    logic [4:0]  rs1, rs2, rd;
    logic [2:0]  funct3;
    logic        funct7_5;

    logic        reg_write, alu_b_src, mem_read, mem_write, branch, jal, jalr;
    logic [1:0]  alu_a_src, result_src;
    logic [3:0]  alu_op;
    logic [2:0]  imm_sel;

    logic [31:0] rs1_data, rs2_data, imm;
    logic [31:0] alu_a, alu_b, alu_result;
    logic        zero, br_taken;

    logic [31:0] mem_rdata, load_result, dmem_wdata;
    logic [3:0]  dmem_be;

    // ---- MMIO decode: peripherals at 0x1000_0000, RAM below ----
    localparam logic [31:0] UART_DATA = 32'h1000_0000;  // W: byte to transmit
    localparam logic [31:0] UART_STAT = 32'h1000_0004;  // R: bit0 = tx_busy
    localparam logic [31:0] CYC_CTR   = 32'h1000_0008;  // R: free-running cycles
    localparam logic [31:0] HALT_REG  = 32'h1000_000C;  // W: any store -> halt
    logic        is_mmio, dmem_we;
    logic [31:0] dmem_rdata, mmio_rdata;

    logic [31:0] write_back, pc_plus4, pc_target;
    logic        pc_load;

    // ---- instruction field extraction ----
    assign opcode   = instr[6:0];
    assign rd       = instr[11:7];
    assign funct3   = instr[14:12];
    assign rs1      = instr[19:15];
    assign rs2      = instr[24:20];
    assign funct7_5 = instr[30];

    // ---- module instances ----
    program_counter u_pc (
        .clk(clk), .rst_n(rst_n), .pc_load(pc_load), .pc_next(pc_target), .pc(pc) );

    instr_memory u_imem ( .addr(pc), .instr(instr) );

    control_unit u_cu (
        .opcode(opcode), .funct3(funct3), .funct7_5(funct7_5),
        .reg_write(reg_write), .alu_a_src(alu_a_src), .alu_b_src(alu_b_src),
        .alu_op(alu_op), .result_src(result_src),
        .mem_read(mem_read), .mem_write(mem_write),
        .branch(branch), .jal(jal), .jalr(jalr), .imm_sel(imm_sel) );

    register_file u_rf (
        .clk(clk), .we(reg_write),
        .rs1_addr(rs1), .rs2_addr(rs2), .rd_addr(rd), .rd_data(write_back),
        .rs1_data(rs1_data), .rs2_data(rs2_data) );

    imm_gen u_imm ( .instr(instr), .imm_sel(imm_sel), .imm(imm) );

    alu u_alu ( .a(alu_a), .b(alu_b), .alu_op(alu_op),
                .result(alu_result), .zero(zero) );

    branch_unit u_br ( .funct3(funct3), .rs1_data(rs1_data), .rs2_data(rs2_data),
                       .taken(br_taken) );

    store_align u_salign ( .funct3(funct3), .addr_lo(alu_result[1:0]),
                           .rs2_data(rs2_data), .wdata(dmem_wdata), .byte_en(dmem_be) );

    // ---- data bus: RAM below 0x1000_0000, MMIO peripherals at/above it ----
    assign is_mmio = alu_result[28];              // 0x1000_0000+ -> peripherals
    assign dmem_we = mem_write & ~is_mmio;        // RAM writes only when NOT mmio

    data_memory u_dmem ( .clk(clk), .mem_write(dmem_we), .byte_en(dmem_be),
                         .addr(alu_result), .write_data(dmem_wdata), .read_data(dmem_rdata) );

    // ---- MMIO peripherals (Phase 1) ----
    // free-running time source, read at CYC_CTR
    logic [31:0] cycles;
    cycle_counter u_cyc ( .clk(clk), .rst_n(rst_n), .count(cycles) );

    // serial out: a store to UART_DATA pulses `start` for one cycle (single-cycle core)
    logic uart_busy, uart_we;
    assign uart_we = mem_write & is_mmio & (alu_result == UART_DATA);
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(115_200)) u_uart (
        .clk(clk), .rst_n(rst_n),
        .start(uart_we), .data(dmem_wdata[7:0]),
        .tx(uart_tx), .busy(uart_busy) );

    // MMIO read mux (combinational; single-cycle load)
    always_comb begin
        case (alu_result[3:2])
            2'd1:    mmio_rdata = {31'd0, uart_busy};   // UART_STATUS bit0 = tx_busy
            2'd2:    mmio_rdata = cycles;               // CYCLE_COUNTER
            default: mmio_rdata = 32'd0;                // UART_DATA / HALT read as 0
        endcase
    end

    assign halt      = mem_write & is_mmio & (alu_result == HALT_REG);
    assign mem_rdata = is_mmio ? mmio_rdata : dmem_rdata;   // load path mux

    load_extend u_lext ( .funct3(funct3), .addr_lo(alu_result[1:0]),
                         .word(mem_rdata), .result(load_result) );

    // ---- datapath muxes ----
    // ALU operand A: rs1 / pc (auipc) / zero (lui)
    always_comb begin
        case (alu_a_src)
            2'd1:    alu_a = pc;
            2'd2:    alu_a = 32'd0;
            default: alu_a = rs1_data;
        endcase
    end
    // ALU operand B: rs2 / immediate
    assign alu_b = alu_b_src ? imm : rs2_data;

    // writeback source: ALU / load / pc+4
    always_comb begin
        case (result_src)
            2'd1:    write_back = load_result;
            2'd2:    write_back = pc_plus4;
            default: write_back = alu_result;
        endcase
    end

    // ---- next-PC logic ----
    assign pc_plus4  = pc + 32'd4;
    assign pc_target = jalr ? (alu_result & ~32'b1)  // jalr: (rs1+imm) & ~1
                            : (pc + imm);            // jal / taken branch
    assign pc_load   = jal | jalr | (branch & br_taken);

    // ---- debug taps ----
    assign debug_pc        = pc;
    assign debug_reg_write = reg_write;
    assign debug_rd        = rd;
    assign debug_result    = write_back;
endmodule
