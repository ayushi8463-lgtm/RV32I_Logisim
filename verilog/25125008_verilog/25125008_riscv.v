/***************************************************************************
* Enrolment: 25125008
*
* Module: 25125008_riscv.v  (top-level)
*
* Top-level module implementing the required project interface.
* Contains the FSM and the shared memory bus arbiter.
*
* The processor is multi-cycle because the interface has mem_rbusy and
* mem_wbusy signals, meaning memory can take more than one clock cycle
* to respond. The FSM handles this by waiting in S_FETCH_WAIT or
* S_MEM_WAIT until the busy signal goes low.
*
* The fetch is split into two states (S_FETCH and S_FETCH_WAIT).
* S_FETCH asserts mem_rstrb for one cycle then moves to S_FETCH_WAIT,
* where rstrb is deasserted and the FSM waits for mem_rbusy to clear.
*
* FSM flow:
*   S_FETCH -> S_FETCH_WAIT -> S_EXECUTE -> S_WRITEBACK -> S_FETCH
*                                        -> S_MEM_WAIT  -> S_WRITEBACK
*
* reset is active-low per the project spec.
***************************************************************************/
`include "riscv_defs.vh"

module riscv_processor (
    input  wire        clk,

    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    output reg  [ 3:0] mem_wmask,
    input  wire [31:0] mem_rdata,
    output reg         mem_rstrb,
    input  wire        mem_rbusy,
    input  wire        mem_wbusy,

    input  wire        reset       // active-low: hold low to reset
);

    reg  [31:0] PC;
    wire [31:0] pc_next   = PC + 32'd4;
    wire [31:0] pc_target;
    wire        pc_mux_sel;

    reg [`FSM_BITS-1:0] state;
    reg [`FSM_BITS-1:0] state_next;

    always @(posedge clk or negedge reset) begin
        if (!reset) state <= `S_FETCH;
        else        state <= state_next;
    end

    wire is_mem_op;
    wire is_mem_write;

    always @(*) begin
        case (state)
            `S_FETCH      : state_next = `S_FETCH_WAIT;
            `S_FETCH_WAIT : state_next = mem_rbusy    ? `S_FETCH_WAIT : `S_EXECUTE;
            `S_EXECUTE    : state_next = is_mem_op     ? `S_MEM_WAIT  : `S_WRITEBACK;
            `S_MEM_WAIT   : state_next = (is_mem_write ? mem_wbusy    : mem_rbusy)
                                         ? `S_MEM_WAIT : `S_WRITEBACK;
            `S_WRITEBACK  : state_next = `S_FETCH;
            default       : state_next = `S_FETCH;
        endcase
    end

    wire fetch_latch_en = (state == `S_FETCH_WAIT) && !mem_rbusy;
    wire execute_en     = (state == `S_EXECUTE);
    wire mem_wait_en    = (state == `S_MEM_WAIT);
    wire writeback_en   = (state == `S_WRITEBACK);

    // last cycle of S_MEM_WAIT — ProcessorCore latches load data here
    // before the bus switches back to the PC address
    wire mem_done = mem_wait_en &&
                    (is_mem_write ? !mem_wbusy : !mem_rbusy);

    always @(posedge clk or negedge reset) begin
        if (!reset)
            PC <= 32'd0;
        else if (writeback_en)
            PC <= pc_mux_sel ? pc_target : pc_next;
    end

    wire [31:0] core_dmem_addr;
    wire        core_dmem_write;
    wire [31:0] core_dmem_wdata;
    wire [ 3:0] core_dmem_wmask;

    ProcessorCore core (
        .clk_i             (clk),
        .reset_i           (!reset),
        .instruction_data_i(mem_rdata),
        .dmem_rdata_i      (mem_rdata),
        .dmem_write_enable_o(core_dmem_write),
        .dmem_wdata_o      (core_dmem_wdata),
        .dmem_wmask_o      (core_dmem_wmask),
        .dmem_addr_o       (core_dmem_addr),
        .fetch_latch_en_i  (fetch_latch_en),
        .execute_en_i      (execute_en),
        .mem_wait_en_i     (mem_wait_en),
        .writeback_en_i    (writeback_en),
        .mem_done_i        (mem_done),
        .is_mem_op_o       (is_mem_op),
        .is_mem_write_o    (is_mem_write),
        .pc_target_o       (pc_target),
        .pc_mux_sel_o      (pc_mux_sel),
        .pc_i              (PC),
        .pc_next_i         (pc_next)
    );

    // bus arbiter — only one of fetch / load / store is active at a time
    always @(*) begin
        if (state == `S_FETCH) begin
            mem_addr  = PC;
            mem_rstrb = 1'b1;
            mem_wdata = 32'b0;
            mem_wmask = 4'b0000;
        end else if (state == `S_FETCH_WAIT) begin
            // hold address stable, deassert rstrb while waiting
            mem_addr  = PC;
            mem_rstrb = 1'b0;
            mem_wdata = 32'b0;
            mem_wmask = 4'b0000;
        end else if (mem_wait_en && is_mem_write) begin
            mem_addr  = core_dmem_addr;
            mem_rstrb = 1'b0;
            mem_wdata = core_dmem_wdata;
            mem_wmask = core_dmem_wmask;
        end else if (mem_wait_en && !is_mem_write) begin
            mem_addr  = core_dmem_addr;
            mem_rstrb = 1'b1;
            mem_wdata = 32'b0;
            mem_wmask = 4'b0000;
        end else begin
            mem_addr  = PC;
            mem_rstrb = 1'b0;
            mem_wdata = 32'b0;
            mem_wmask = 4'b0000;
        end
    end

endmodule
