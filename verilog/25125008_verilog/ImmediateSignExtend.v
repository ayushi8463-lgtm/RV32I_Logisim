/***************************************************************************
* Enrolment: 25125008
*
* Module: ImmediateSignExtend.v
*
* Reconstructs the immediate value from whichever of the 5 RV32I
* instruction formats is active. The bits are scattered across the
* instruction word in different positions for each format — this is
* intentional in the spec so that rs1/rs2/rd are always at the same
* positions regardless of format.
*
* The sign bit is always instruction[31] for all formats.
*
* Bit positions per format:
*   I : imm[11:0]  = inst[31:20]
*   S : imm[11:5]  = inst[31:25],  imm[4:0]  = inst[11:7]
*   B : imm[12]    = inst[31],     imm[11]   = inst[7],
*       imm[10:5]  = inst[30:25],  imm[4:1]  = inst[11:8]
*   U : imm[31:12] = inst[31:12],  lower 12 bits zeroed
*   J : imm[20]    = inst[31],     imm[10:1] = inst[30:21],
*       imm[11]    = inst[20],     imm[19:12]= inst[19:12]
*
* The signed wire approach is used instead of $signed() on part-selects
* because iVerilog does not support $signed() on part-selects inside
* always blocks.
***************************************************************************/
`include "riscv_defs.vh"

module ImmediateSignExtend #(
    parameter XLEN = `XLEN
)(
    output reg  [XLEN-1:0] imm_o,
    input  wire [XLEN-1:7] imm_i,       // instruction[31:7]; [6:0] is the opcode
    input  wire [`IMM_SEL_BITS-1:0] imm_sel_i
);

    // declared signed so that MSB replication works correctly in the
    // concatenations below
    wire signed [11:0] i_raw = imm_i[31:20];
    wire signed [11:0] s_raw = {imm_i[31:25], imm_i[11:7]};
    wire signed [12:0] b_raw = {imm_i[31], imm_i[7], imm_i[30:25], imm_i[11:8], 1'b0};
    wire signed [20:0] j_raw = {imm_i[31], imm_i[19:12], imm_i[20], imm_i[30:21], 1'b0};

    always @(*) begin
        case (imm_sel_i)
            `IMM_I_TYPE : imm_o = {{20{i_raw[11]}}, i_raw};
            `IMM_S_TYPE : imm_o = {{20{s_raw[11]}}, s_raw};
            `IMM_B_TYPE : imm_o = {{19{b_raw[12]}}, b_raw};
            `IMM_U_TYPE : imm_o = {imm_i[31:12], 12'b0};
            `IMM_J_TYPE : imm_o = {{11{j_raw[20]}}, j_raw};
            default     : imm_o = {XLEN{1'b0}};
        endcase
    end

endmodule
