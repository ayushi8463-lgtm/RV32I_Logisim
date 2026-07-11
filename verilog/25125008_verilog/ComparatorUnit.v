/***************************************************************************
* Enrolment: 25125008
*
* Module: ComparatorUnit.v
*
* Evaluates branch conditions and produces the 1-bit result also used
* for SLT/SLTU write-back.
*
* Running this separately from the ALU means the branch target address
* (PC + imm, computed in the ALU) and the branch condition can both be
* ready in the same cycle without needing an extra adder.
*
* BLT and BGE need signed comparison. In Verilog, < and >= are unsigned
* by default, so the inputs are assigned to signed wires first.
* BLTU and BGEU stay unsigned.
***************************************************************************/
`include "riscv_defs.vh"

module ComparatorUnit #(
    parameter XLEN = `XLEN
)(
    output reg             comp_o,
    input  wire [XLEN-1:0] comp_port_a_i,
    input  wire [XLEN-1:0] comp_port_b_i,
    input  wire [`COMP_SEL_BITS-1:0] comp_op_sel_i
);

    // signed wires for BLT/BGE/SLT — Verilog needs the wire declared
    // signed, not just a cast at the point of use
    wire signed [XLEN-1:0] a_s = comp_port_a_i;
    wire signed [XLEN-1:0] b_s = comp_port_b_i;

    always @(*) begin
        case (comp_op_sel_i)
            `COMP_BEQ  : comp_o = (comp_port_a_i == comp_port_b_i);
            `COMP_BNE  : comp_o = (comp_port_a_i != comp_port_b_i);
            `COMP_BLT  : comp_o = (a_s < b_s);
            `COMP_BGE  : comp_o = (a_s >= b_s);
            `COMP_BLTU : comp_o = (comp_port_a_i < comp_port_b_i);
            `COMP_BGEU : comp_o = (comp_port_a_i >= comp_port_b_i);
            default    : comp_o = 1'b0;
        endcase
    end

endmodule
