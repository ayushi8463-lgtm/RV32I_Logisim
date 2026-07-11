/***************************************************************************
* Enrolment: 25125008
*
* Module: ArithmeticLogicUnit.v
*
* Handles all arithmetic and logic operations. SLT/SLTU are not done
* here — those go through the ComparatorUnit so the branch condition
* and branch target address can both be computed in the same cycle.
*
* The shift amount is taken from the lower 5 bits of port_b only,
* as per the RV32I spec. For SRA the input needs to be treated as
* signed so the MSB gets replicated on the right shift — the signed
* wire declaration handles this in plain Verilog.
*
* ALU_OP_PASS_B is used for LUI, where the immediate just needs to
* pass straight through to the write-back without any addition.
***************************************************************************/
`include "riscv_defs.vh"

module ArithmeticLogicUnit #(
    parameter XLEN           = `XLEN,
    parameter REG_ADDR_WIDTH = `REG_ADDR_WIDTH
)(
    output reg  [XLEN-1:0]  alu_o,
    input  wire [XLEN-1:0]  alu_port_a_i,
    input  wire [XLEN-1:0]  alu_port_b_i,
    input  wire [`ALU_SEL_BITS-1:0] alu_op_sel_i
);

    // needed for arithmetic right shift — without signed declaration,
    // >>> just does a logical shift in Verilog
    wire signed [XLEN-1:0] port_a_s = alu_port_a_i;

    // spec says only the lower 5 bits of rs2 are used as shift amount
    wire [4:0] shamt = alu_port_b_i[REG_ADDR_WIDTH-1:0];

    always @(*) begin
        case (alu_op_sel_i)
            `ALU_OP_ADD    : alu_o = alu_port_a_i + alu_port_b_i;
            `ALU_OP_SUB    : alu_o = alu_port_a_i - alu_port_b_i;
            `ALU_OP_AND    : alu_o = alu_port_a_i & alu_port_b_i;
            `ALU_OP_OR     : alu_o = alu_port_a_i | alu_port_b_i;
            `ALU_OP_XOR    : alu_o = alu_port_a_i ^ alu_port_b_i;
            `ALU_OP_SLL    : alu_o = alu_port_a_i << shamt;
            `ALU_OP_SRL    : alu_o = alu_port_a_i >> shamt;
            `ALU_OP_SRA    : alu_o = port_a_s     >>> shamt;
            `ALU_OP_PASS_B : alu_o = alu_port_b_i;
            default        : alu_o = {XLEN{1'b0}};
        endcase
    end

endmodule
