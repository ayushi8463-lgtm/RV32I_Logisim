/***************************************************************************
* Enrolment: 25125008
*
* Module: LoadStoreUnit.v
*
* Handles sub-word loads and stores.
*
* The memory bus returns a full 32-bit word, so for byte and halfword
* accesses we use addr[1:0] to pick the right byte lanes within that word.
* The offset shifts data on both the load and store paths.
*
* For loads, sign or zero extension happens after the byte/half is selected.
* For stores, both the data and the write strobe are shifted to the correct
* lane based on addr[1:0].
***************************************************************************/
`include "riscv_defs.vh"

module LoadStoreUnit #(
    parameter XLEN = `XLEN
)(
    output reg  [XLEN-1:0] read_data_o,
    input  wire [XLEN-1:0] read_data_i,
    output reg  [XLEN-1:0] write_data_o,
    input  wire [XLEN-1:0] write_data_i,
    output reg  [3:0]       write_data_strobe_o,
    input  wire [`LS_SEL_BITS-1:0] load_store_type_i,
    input  wire [1:0]       addr_offset_i          // addr[1:0] from ALU result
);

    // extract the correct byte/half from the word based on offset
    wire [7:0]  byte_sel = read_data_i >> ({3'b0, addr_offset_i} * 8);
    wire [15:0] half_sel = read_data_i >> ({3'b0, addr_offset_i[1]} * 16);

    // signed versions for sign-extension
    wire signed [7:0]  byte_s = byte_sel;
    wire signed [15:0] half_s = half_sel;

    // load path
    always @(*) begin
        case (load_store_type_i)
            `LS_LB  : read_data_o = {{24{byte_s[7]}},  byte_s};
            `LS_LBU : read_data_o = {{24{1'b0}},        byte_sel};
            `LS_LH  : read_data_o = {{16{half_s[15]}}, half_s};
            `LS_LHU : read_data_o = {{16{1'b0}},        half_sel};
            `LS_LW  : read_data_o = read_data_i;
            default : read_data_o = read_data_i;
        endcase
    end

    // store path — shift data and mask to the correct byte lane
    always @(*) begin
        case (load_store_type_i)
            `LS_SB : begin
                write_data_o        = {24'b0, write_data_i[7:0]} << ({3'b0, addr_offset_i} * 8);
                write_data_strobe_o = 4'b0001 << addr_offset_i;
            end
            `LS_SH : begin
                write_data_o        = {16'b0, write_data_i[15:0]} << ({3'b0, addr_offset_i[1]} * 16);
                write_data_strobe_o = 4'b0011 << {addr_offset_i[1], 1'b0};
            end
            `LS_SW : begin
                write_data_o        = write_data_i;
                write_data_strobe_o = 4'b1111;
            end
            default : begin
                write_data_o        = write_data_i;
                write_data_strobe_o = 4'b0000;
            end
        endcase
    end

endmodule
