/***************************************************************************
* Enrolment: 25125008
*
* Module: CoreControlUnit.v
*
* Decodes the instruction and generates all the control signals for
* the datapath. This is purely combinational — no state held here.
*
* The R-type inner case uses {funct7_bit5_i, funct3_i} as the key
* because funct3 alone is not enough to tell apart ADD from SUB, or
* SRL from SRA — funct7[5] is what distinguishes them.
*
* For I-type shifts (SLLI/SRLI/SRAI), the shift amount lives in
* imm[4:0] and the ALU picks it up from port_b[4:0] automatically.
* SRAI vs SRLI is differentiated by funct7[5], same as the R-type case.
*
* LUI uses ALU_OP_PASS_B so the immediate goes straight to write-back
* without being added to anything. AUIPC uses ALU_OP_ADD with PC as
* port_a, which gives PC + (imm<<12).
*
* For branches, pc_mux_sel is driven by the live comparator output
* rather than a fixed decode value, so it only goes high if the
* condition actually holds at runtime.
*
* All outputs are set to safe inactive values at the top of the always
* block so that any unrecognised opcode does nothing.
***************************************************************************/
`include "riscv_defs.vh"

module CoreControlUnit #(
    parameter XLEN = `XLEN
)(
    output reg                          pc_mux_sel_o,
    output reg                          reg_write_enable_o,
    output reg  [`IMM_SEL_BITS-1:0]    imm_select_o,
    output reg                          execute_port_a_sel_o,  // 1=rs1, 0=PC
    output reg                          execute_port_b_sel_o,  // 1=rs2, 0=imm
    output reg                          comp_port_b_sel_o,     // 1=imm, 0=rs2
    output reg  [`ALU_SEL_BITS-1:0]    alu_op_sel_o,
    output reg  [`COMP_SEL_BITS-1:0]   comp_op_sel_o,
    output reg  [`LS_SEL_BITS-1:0]     load_store_type_o,
    output reg                          data_memory_write_o,
    output reg  [`RD_SEL_BITS-1:0]     reg_write_data_sel_o,

    input  wire [6:0]                   op_code_i,
    input  wire [2:0]                   funct3_i,
    input  wire                         funct7_bit5_i,
    input  wire                         branch_enable_i
);

    localparam OP_R_TYPE  = 7'b0110011;
    localparam OP_I_ALU   = 7'b0010011;
    localparam OP_I_LOAD  = 7'b0000011;
    localparam OP_I_JALR  = 7'b1100111;
    localparam OP_I_FENCE = 7'b0001111;
    localparam OP_S_TYPE  = 7'b0100011;
    localparam OP_B_TYPE  = 7'b1100011;
    localparam OP_U_LUI   = 7'b0110111;
    localparam OP_U_AUIPC = 7'b0010111;
    localparam OP_J_TYPE  = 7'b1101111;

    always @(*) begin
        // defaults — safe values so nothing unexpected happens on an
        // unknown opcode, and so no latches are inferred
        pc_mux_sel_o         = 1'b0;
        reg_write_enable_o   = 1'b0;
        imm_select_o         = `IMM_UNKNOWN_TYPE;
        execute_port_a_sel_o = 1'b1;
        execute_port_b_sel_o = 1'b0;
        comp_port_b_sel_o    = 1'b0;
        alu_op_sel_o         = `ALU_OP_UNK;
        comp_op_sel_o        = `COMP_NONE;
        load_store_type_o    = `LS_NA;
        data_memory_write_o  = 1'b0;
        reg_write_data_sel_o = `RD_MUX_NA;

        case (op_code_i)

            OP_R_TYPE : begin
                reg_write_enable_o   = 1'b1;
                imm_select_o         = `IMM_UNKNOWN_TYPE;
                execute_port_a_sel_o = 1'b1;
                execute_port_b_sel_o = 1'b1;
                comp_port_b_sel_o    = 1'b0;

                // need both funct7[5] and funct3 to uniquely identify each op
                case ({funct7_bit5_i, funct3_i})
                    4'b0_000: begin alu_op_sel_o = `ALU_OP_ADD; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // ADD
                    4'b1_000: begin alu_op_sel_o = `ALU_OP_SUB; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // SUB
                    4'b0_001: begin alu_op_sel_o = `ALU_OP_SLL; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // SLL
                    4'b0_010: begin alu_op_sel_o = `ALU_OP_UNK; comp_op_sel_o = `COMP_BLT;  reg_write_data_sel_o = `RD_MUX_COMP; end // SLT
                    4'b0_011: begin alu_op_sel_o = `ALU_OP_UNK; comp_op_sel_o = `COMP_BLTU; reg_write_data_sel_o = `RD_MUX_COMP; end // SLTU
                    4'b0_100: begin alu_op_sel_o = `ALU_OP_XOR; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // XOR
                    4'b0_101: begin alu_op_sel_o = `ALU_OP_SRL; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // SRL
                    4'b1_101: begin alu_op_sel_o = `ALU_OP_SRA; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // SRA
                    4'b0_110: begin alu_op_sel_o = `ALU_OP_OR;  comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // OR
                    4'b0_111: begin alu_op_sel_o = `ALU_OP_AND; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // AND
                    default:  begin alu_op_sel_o = `ALU_OP_UNK; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_NA;   end
                endcase
            end

            OP_I_ALU : begin
                reg_write_enable_o   = 1'b1;
                imm_select_o         = `IMM_I_TYPE;
                execute_port_a_sel_o = 1'b1;
                execute_port_b_sel_o = 1'b0;   // immediate to ALU
                comp_port_b_sel_o    = 1'b1;   // immediate to comparator (SLTI/SLTIU)

                case (funct3_i)
                    3'b000: begin alu_op_sel_o = `ALU_OP_ADD; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // ADDI
                    3'b001: begin alu_op_sel_o = `ALU_OP_SLL; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // SLLI
                    3'b010: begin alu_op_sel_o = `ALU_OP_UNK; comp_op_sel_o = `COMP_BLT;  reg_write_data_sel_o = `RD_MUX_COMP; end // SLTI
                    3'b011: begin alu_op_sel_o = `ALU_OP_UNK; comp_op_sel_o = `COMP_BLTU; reg_write_data_sel_o = `RD_MUX_COMP; end // SLTIU
                    3'b100: begin alu_op_sel_o = `ALU_OP_XOR; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // XORI
                    3'b101: begin                                                                                                    // SRLI / SRAI
                        alu_op_sel_o         = funct7_bit5_i ? `ALU_OP_SRA : `ALU_OP_SRL;
                        comp_op_sel_o        = `COMP_NONE;
                        reg_write_data_sel_o = `RD_MUX_ALU;
                    end
                    3'b110: begin alu_op_sel_o = `ALU_OP_OR;  comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // ORI
                    3'b111: begin alu_op_sel_o = `ALU_OP_AND; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_ALU;  end // ANDI
                    default: begin alu_op_sel_o = `ALU_OP_UNK; comp_op_sel_o = `COMP_NONE; reg_write_data_sel_o = `RD_MUX_NA;  end
                endcase
            end

            OP_I_LOAD : begin
                reg_write_enable_o   = 1'b1;
                imm_select_o         = `IMM_I_TYPE;
                execute_port_a_sel_o = 1'b1;
                execute_port_b_sel_o = 1'b0;
                alu_op_sel_o         = `ALU_OP_ADD;   // address = rs1 + imm
                comp_op_sel_o        = `COMP_NONE;
                reg_write_data_sel_o = `RD_MUX_DMEM;

                case (funct3_i)
                    3'b000: load_store_type_o = `LS_LB;
                    3'b001: load_store_type_o = `LS_LH;
                    3'b010: load_store_type_o = `LS_LW;
                    3'b100: load_store_type_o = `LS_LBU;
                    3'b101: load_store_type_o = `LS_LHU;
                    default: load_store_type_o = `LS_LW;
                endcase
            end

            OP_S_TYPE : begin
                reg_write_enable_o   = 1'b0;
                imm_select_o         = `IMM_S_TYPE;
                execute_port_a_sel_o = 1'b1;
                execute_port_b_sel_o = 1'b0;
                alu_op_sel_o         = `ALU_OP_ADD;   // address = rs1 + imm
                comp_op_sel_o        = `COMP_NONE;
                data_memory_write_o  = 1'b1;
                reg_write_data_sel_o = `RD_MUX_NA;

                case (funct3_i)
                    3'b000: load_store_type_o = `LS_SB;
                    3'b001: load_store_type_o = `LS_SH;
                    3'b010: load_store_type_o = `LS_SW;
                    default: load_store_type_o = `LS_SW;
                endcase
            end

            OP_B_TYPE : begin
                pc_mux_sel_o         = branch_enable_i;   // only jump if condition holds
                reg_write_enable_o   = 1'b0;
                imm_select_o         = `IMM_B_TYPE;
                execute_port_a_sel_o = 1'b0;   // PC as base for target calculation
                execute_port_b_sel_o = 1'b0;
                comp_port_b_sel_o    = 1'b0;
                alu_op_sel_o         = `ALU_OP_ADD;   // target = PC + imm
                reg_write_data_sel_o = `RD_MUX_NA;

                case (funct3_i)
                    3'b000: comp_op_sel_o = `COMP_BEQ;
                    3'b001: comp_op_sel_o = `COMP_BNE;
                    3'b100: comp_op_sel_o = `COMP_BLT;
                    3'b101: comp_op_sel_o = `COMP_BGE;
                    3'b110: comp_op_sel_o = `COMP_BLTU;
                    3'b111: comp_op_sel_o = `COMP_BGEU;
                    default: comp_op_sel_o = `COMP_NONE;
                endcase
            end

            OP_I_JALR : begin
                pc_mux_sel_o         = 1'b1;
                reg_write_enable_o   = 1'b1;
                imm_select_o         = `IMM_I_TYPE;
                execute_port_a_sel_o = 1'b1;   // rs1
                execute_port_b_sel_o = 1'b0;
                alu_op_sel_o         = `ALU_OP_ADD;   // target = rs1 + imm (LSB cleared in ProcessorCore)
                comp_op_sel_o        = `COMP_NONE;
                reg_write_data_sel_o = `RD_MUX_PC4;
            end

            OP_J_TYPE : begin
                pc_mux_sel_o         = 1'b1;
                reg_write_enable_o   = 1'b1;
                imm_select_o         = `IMM_J_TYPE;
                execute_port_a_sel_o = 1'b0;   // PC
                execute_port_b_sel_o = 1'b0;
                alu_op_sel_o         = `ALU_OP_ADD;
                comp_op_sel_o        = `COMP_NONE;
                reg_write_data_sel_o = `RD_MUX_PC4;
            end

            OP_U_LUI : begin
                // rd = imm<<12; the immediate generator already has the
                // lower 12 bits zeroed, so just pass it straight through
                reg_write_enable_o   = 1'b1;
                imm_select_o         = `IMM_U_TYPE;
                execute_port_a_sel_o = 1'b0;
                execute_port_b_sel_o = 1'b0;
                alu_op_sel_o         = `ALU_OP_PASS_B;
                comp_op_sel_o        = `COMP_NONE;
                reg_write_data_sel_o = `RD_MUX_ALU;
            end

            OP_U_AUIPC : begin
                // rd = PC + (imm<<12)
                reg_write_enable_o   = 1'b1;
                imm_select_o         = `IMM_U_TYPE;
                execute_port_a_sel_o = 1'b0;   // PC
                execute_port_b_sel_o = 1'b0;
                alu_op_sel_o         = `ALU_OP_ADD;
                comp_op_sel_o        = `COMP_NONE;
                reg_write_data_sel_o = `RD_MUX_ALU;
            end

            OP_I_FENCE : begin
                // treated as NOP — single core, no caches
            end

            default : begin
                // unknown opcode — all outputs stay at safe defaults
            end

        endcase
    end

endmodule
