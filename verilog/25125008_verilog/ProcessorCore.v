/***************************************************************************
* Enrolment: 25125008
*
* Module: ProcessorCore.v
*
* Instantiates and connects all the datapath sub-modules. The FSM and
* PC register live in the top-level; this module is purely combinational
* apart from two registers:
*
*   instr_reg     — holds the instruction stable across the whole
*                   execute/memory/writeback sequence
*   load_data_reg — latches the load result before the bus switches
*                   back to the PC address in S_WRITEBACK
*
* The load data latch is needed because the processor uses a shared
* Von Neumann bus. When S_MEM_WAIT finishes and we move to S_WRITEBACK,
* the bus arbiter puts PC back on mem_addr so the next fetch can start,
* which means mem_rdata no longer holds the loaded value. We latch it
* on the last cycle of S_MEM_WAIT (mem_done_i) before that happens.
*
* JALR requires the target address LSB to be cleared to 0 (spec §2.5).
* That is done here in pc_target_o before passing it to the FSM.
*
* The write enable for data memory is gated on mem_wait_en_i only —
* not execute_en_i — because during S_EXECUTE the bus still shows the
* PC address, not the store address.
***************************************************************************/
`include "riscv_defs.vh"

module ProcessorCore (
    input  wire        clk_i,
    input  wire        reset_i,

    input  wire [31:0] instruction_data_i,
    input  wire [31:0] dmem_rdata_i,

    output wire        dmem_write_enable_o,
    output wire [31:0] dmem_wdata_o,
    output wire [ 3:0] dmem_wmask_o,
    output wire [31:0] dmem_addr_o,

    input  wire        fetch_latch_en_i,
    input  wire        execute_en_i,
    input  wire        mem_wait_en_i,
    input  wire        writeback_en_i,
    input  wire        mem_done_i,

    output wire        is_mem_op_o,
    output wire        is_mem_write_o,
    output wire [31:0] pc_target_o,
    output wire        pc_mux_sel_o,

    input  wire [31:0] pc_i,
    input  wire [31:0] pc_next_i
);

    // instruction latch
    reg [31:0] instr_reg;
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i)
            instr_reg <= 32'h0000_0013;   // NOP
        else if (fetch_latch_en_i)
            instr_reg <= instruction_data_i;
    end

    wire [6:0] opcode   = instr_reg[6:0];
    wire [4:0] rd_addr  = instr_reg[11:7];
    wire [2:0] funct3   = instr_reg[14:12];
    wire [4:0] rs1_addr = instr_reg[19:15];
    wire [4:0] rs2_addr = instr_reg[24:20];
    wire       funct7b5 = instr_reg[30];

    // load data latch — see module header for why this is needed
    wire [31:0] raw_load_data;
    reg  [31:0] load_data_reg;
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i)
            load_data_reg <= 32'b0;
        else if (mem_done_i)
            load_data_reg <= raw_load_data;
    end

    wire [31:0] reg_src1, reg_src2;
    wire [31:0] immediate;
    wire [31:0] alu_port_a, alu_port_b, comp_port_b;
    wire [31:0] alu_result;
    wire        comp_result;
    wire [31:0] store_data;
    wire [ 3:0] store_strobe;
    wire [31:0] reg_write_data;

    wire                        reg_write_enable;
    wire [`IMM_SEL_BITS-1:0]   imm_select;
    wire                        exec_port_a_sel;
    wire                        exec_port_b_sel;
    wire                        comp_port_b_sel;
    wire [`ALU_SEL_BITS-1:0]   alu_op_sel;
    wire [`COMP_SEL_BITS-1:0]  comp_op_sel;
    wire [`LS_SEL_BITS-1:0]    load_store_type;
    wire                        dmem_write;
    wire [`RD_SEL_BITS-1:0]    reg_wd_sel;

    RegisterFile #(
        .XLEN(`XLEN),
        .REG_ADDR_WIDTH(`REG_ADDR_WIDTH)
    ) regfile (
        .read_data_1_o   (reg_src1),
        .read_data_2_o   (reg_src2),
        .clk_i           (clk_i),
        .write_enable_i  (reg_write_enable & writeback_en_i),
        .write_data_i    (reg_write_data),
        .write_address_i (rd_addr),
        .read_address_1_i(rs1_addr),
        .read_address_2_i(rs2_addr)
    );

    ImmediateSignExtend #(.XLEN(`XLEN)) ise (
        .imm_o    (immediate),
        .imm_i    (instr_reg[31:7]),
        .imm_sel_i(imm_select)
    );

    CoreControlUnit #(.XLEN(`XLEN)) ccu (
        .pc_mux_sel_o        (pc_mux_sel_o),
        .reg_write_enable_o  (reg_write_enable),
        .imm_select_o        (imm_select),
        .execute_port_a_sel_o(exec_port_a_sel),
        .execute_port_b_sel_o(exec_port_b_sel),
        .comp_port_b_sel_o   (comp_port_b_sel),
        .alu_op_sel_o        (alu_op_sel),
        .comp_op_sel_o       (comp_op_sel),
        .load_store_type_o   (load_store_type),
        .data_memory_write_o (dmem_write),
        .reg_write_data_sel_o(reg_wd_sel),
        .op_code_i           (opcode),
        .funct3_i            (funct3),
        .funct7_bit5_i       (funct7b5),
        .branch_enable_i     (comp_result)
    );

    assign alu_port_a  = exec_port_a_sel ? reg_src1 : pc_i;
    assign alu_port_b  = exec_port_b_sel ? reg_src2 : immediate;
    assign comp_port_b = comp_port_b_sel ? immediate : reg_src2;

    ArithmeticLogicUnit #(
        .XLEN(`XLEN),
        .REG_ADDR_WIDTH(`REG_ADDR_WIDTH)
    ) alu (
        .alu_o        (alu_result),
        .alu_port_a_i (alu_port_a),
        .alu_port_b_i (alu_port_b),
        .alu_op_sel_i (alu_op_sel)
    );

    ComparatorUnit #(.XLEN(`XLEN)) cmp (
        .comp_o       (comp_result),
        .comp_port_a_i(reg_src1),
        .comp_port_b_i(comp_port_b),
        .comp_op_sel_i(comp_op_sel)
    );

    LoadStoreUnit #(.XLEN(`XLEN)) lsu (
        .read_data_o        (raw_load_data),
        .read_data_i        (dmem_rdata_i),
        .write_data_o       (store_data),
        .write_data_i       (reg_src2),
        .write_data_strobe_o(store_strobe),
        .load_store_type_i  (load_store_type),
        .addr_offset_i      (alu_result[1:0])   // byte lane select
    );

    // only assert write enable during S_MEM_WAIT, not S_EXECUTE
    assign dmem_write_enable_o = dmem_write & mem_wait_en_i;
    assign dmem_wdata_o        = store_data;
    assign dmem_wmask_o        = store_strobe;
    assign dmem_addr_o         = alu_result;

    assign is_mem_op_o    = (load_store_type != `LS_NA);
    assign is_mem_write_o = dmem_write;

    // JALR: spec requires bit 0 of the target to be cleared
    assign pc_target_o = (opcode == 7'b1100111) ?
                         {alu_result[31:1], 1'b0} : alu_result;

    reg [31:0] reg_write_data_r;
    always @(*) begin
        case (reg_wd_sel)
            `RD_MUX_ALU  : reg_write_data_r = alu_result;
            `RD_MUX_DMEM : reg_write_data_r = load_data_reg;
            `RD_MUX_COMP : reg_write_data_r = {{31{1'b0}}, comp_result};
            `RD_MUX_IMM  : reg_write_data_r = immediate;
            `RD_MUX_PC4  : reg_write_data_r = pc_next_i;
            default       : reg_write_data_r = {32{1'b0}};
        endcase
    end
    assign reg_write_data = reg_write_data_r;

endmodule
