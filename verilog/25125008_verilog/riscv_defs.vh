/***************************************************************************
* Enrolment: 25125008
*
* File: riscv_defs.vh
*
* Shared constants used across all modules. Since we are using plain
* Verilog (not SystemVerilog), enums are not available, so everything
* is defined here as macros and included where needed.
***************************************************************************/
`ifndef RISCV_DEFS_VH
`define RISCV_DEFS_VH

// Datapath width — RV32I is 32-bit
`define XLEN            32
`define REG_ADDR_WIDTH   5

// Immediate format (which of the 5 RV32I encoding formats to decode)
`define IMM_SEL_BITS     3
`define IMM_I_TYPE       3'd0
`define IMM_S_TYPE       3'd1
`define IMM_B_TYPE       3'd2
`define IMM_U_TYPE       3'd3
`define IMM_J_TYPE       3'd4
`define IMM_UNKNOWN_TYPE 3'd5

// ALU operation codes
`define ALU_SEL_BITS  4
`define ALU_OP_ADD    4'd0
`define ALU_OP_SUB    4'd1
`define ALU_OP_AND    4'd2
`define ALU_OP_OR     4'd3
`define ALU_OP_XOR    4'd4
`define ALU_OP_SLL    4'd5   // shift left logical
`define ALU_OP_SRL    4'd6   // shift right logical
`define ALU_OP_SRA    4'd7   // shift right arithmetic
`define ALU_OP_PASS_B 4'd8   // pass port_b through (used for LUI)
`define ALU_OP_UNK    4'd9   // comparator handles this case

// Branch / comparison condition codes
`define COMP_SEL_BITS  3
`define COMP_BEQ       3'd0
`define COMP_BNE       3'd1
`define COMP_BLT       3'd2   // signed
`define COMP_BGE       3'd3   // signed
`define COMP_BLTU      3'd4   // unsigned
`define COMP_BGEU      3'd5   // unsigned
`define COMP_NONE      3'd6

// Write-back mux select — where does rd get its value from
`define RD_SEL_BITS    3
`define RD_MUX_ALU     3'd0
`define RD_MUX_DMEM    3'd1
`define RD_MUX_COMP    3'd2   // SLT/SLTU result
`define RD_MUX_IMM     3'd3   // LUI
`define RD_MUX_PC4     3'd4   // JAL/JALR link address
`define RD_MUX_NA      3'd5   // no write-back needed

// Load/store type
`define LS_SEL_BITS    4
`define LS_LW          4'd0
`define LS_LH          4'd1   // sign-extend
`define LS_LHU         4'd2   // zero-extend
`define LS_LB          4'd3   // sign-extend
`define LS_LBU         4'd4   // zero-extend
`define LS_SW          4'd5
`define LS_SH          4'd6
`define LS_SB          4'd7
`define LS_NA          4'd8

// FSM states
`define FSM_BITS       3
`define S_FETCH        3'd0
`define S_FETCH_WAIT   3'd1
`define S_EXECUTE      3'd2
`define S_MEM_WAIT     3'd3
`define S_WRITEBACK    3'd4

`endif
