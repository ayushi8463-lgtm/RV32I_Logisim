/***************************************************************************
* Enrolment: 25125008
*
* Module: RegisterFile.v
*
* 32 general-purpose 32-bit registers (x0 to x31).
* x0 is always zero — reads return 0 and writes are ignored.
*
* Writes happen on the negative clock edge so that a value written
* during S_WRITEBACK is available to the read ports by the next
* positive edge (the start of the next instruction's fetch).
*
* Registers are zeroed at the start of simulation so there is no
* undefined state during testing.
***************************************************************************/
`include "riscv_defs.vh"

module RegisterFile #(
    parameter XLEN           = `XLEN,
    parameter REG_ADDR_WIDTH = `REG_ADDR_WIDTH
)(
    output wire [XLEN-1:0]            read_data_1_o,
    output wire [XLEN-1:0]            read_data_2_o,
    input  wire                       clk_i,
    input  wire                       write_enable_i,
    input  wire [XLEN-1:0]            write_data_i,
    input  wire [REG_ADDR_WIDTH-1:0]  write_address_i,
    input  wire [REG_ADDR_WIDTH-1:0]  read_address_1_i,
    input  wire [REG_ADDR_WIDTH-1:0]  read_address_2_i
);

    reg [XLEN-1:0] registers [0:(1<<REG_ADDR_WIDTH)-1];

    integer init_i;
    initial begin
        for (init_i = 0; init_i < (1<<REG_ADDR_WIDTH); init_i = init_i + 1)
            registers[init_i] = {XLEN{1'b0}};
    end

    // x0 always reads as zero
    assign read_data_1_o = (read_address_1_i == {REG_ADDR_WIDTH{1'b0}}) ?
                           {XLEN{1'b0}} : registers[read_address_1_i];
    assign read_data_2_o = (read_address_2_i == {REG_ADDR_WIDTH{1'b0}}) ?
                           {XLEN{1'b0}} : registers[read_address_2_i];

    // write on negedge, skip if rd = x0
    always @(negedge clk_i) begin
        if (write_enable_i && (write_address_i != {REG_ADDR_WIDTH{1'b0}}))
            registers[write_address_i] <= write_data_i;
    end

endmodule
