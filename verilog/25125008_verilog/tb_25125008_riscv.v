/***************************************************************************
* Enrolment: 25125008
*
* Module: tb_25125008_riscv.v  (testbench — plain Verilog, 47 tests)
*
* Covers all 37 RV32I instructions plus 10 note-behaviour tests = 47 tests.
* See tb_25125008_riscv.sv for full test documentation.
*
* Compile:
*   iverilog -g2005 -o sim \
*     riscv_defs.vh ArithmeticLogicUnit.v ComparatorUnit.v \
*     ImmediateSignExtend.v RegisterFile.v LoadStoreUnit.v \
*     CoreControlUnit.v ProcessorCore.v 25125008_riscv.v \
*     tb_25125008_riscv.v
* Run:
*   vvp sim
***************************************************************************/
`timescale 1ns/1ps
`include "riscv_defs.vh"

module tb_25125008_riscv;

    reg         clk;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wmask;
    reg  [31:0] mem_rdata;
    wire        mem_rstrb;
    wire        mem_rbusy;
    wire        mem_wbusy;
    reg         reset;

    // DUT
    riscv_processor dut (
        .clk      (clk),
        .mem_addr (mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        .reset    (reset)
    );

    // ------------------------------------------------------------------
    // Zero-latency SRAM model (valid per spec: rbusy=0 means "not busy").
    // Data area at byte 0x600 (word 384), above code (ends at ~byte 0x444).
    // ------------------------------------------------------------------
    parameter MEM_WORDS = 1024;
    reg [31:0] mem [0:MEM_WORDS-1];

    assign mem_rbusy = 1'b0;
    assign mem_wbusy = 1'b0;
    // mem_rdata is driven combinationally from mem[] via always block
    // (plain Verilog cannot use continuous assign on a reg array element)

    always @(*) begin
        mem_rdata = mem[mem_addr[31:2]];
    end

    always @(posedge clk) begin
        if (mem_wmask[0]) mem[mem_addr[31:2]][ 7: 0] <= mem_wdata[ 7: 0];
        if (mem_wmask[1]) mem[mem_addr[31:2]][15: 8] <= mem_wdata[15: 8];
        if (mem_wmask[2]) mem[mem_addr[31:2]][23:16] <= mem_wdata[23:16];
        if (mem_wmask[3]) mem[mem_addr[31:2]][31:24] <= mem_wdata[31:24];
    end

    initial clk = 0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Per-test pass/fail display using a task with a case statement.
    // Plain Verilog has no 'string' type; test names are printed inline.
    // ------------------------------------------------------------------
    task print_test_name;
        input integer tnum;
        begin
        case (tnum)
            1: $write("ADD: 15+10=25");
            2: $write("SUB: 15-10=5");
            3: $write("XOR: 0xA^0xC=0x6");
            4: $write("OR: 0xA|0xC=0xE");
            5: $write("AND: 0xA&0xC=0x8");
            6: $write("SLL: 1<<4=16");
            7: $write("SRL: 64>>3=8  [NOTE: logical, zero-fills MSB]");
            8: $write("SRL NOTE: 0x80000000>>1=0x40000000 (zero-fills, not 0xC0000000)");
            9: $write("SRA: -8>>2=-2  [NOTE: msb-extends]");
            10: $write("SRA NOTE: -8>>2=-2 (MSB=1 preserved, not zero-filled)");
            11: $write("SLT: -1<0 (signed) => rd=1");
            12: $write("SLTU: 1<2 (unsigned) => rd=1");
            13: $write("SLTU NOTE: -1(=0xFFFFFFFF) > 1 unsigned => rd=0 (zero-extends)");
            14: $write("ADDI: 100+(-3)=97");
            15: $write("XORI: 0xFF^0x0F=0xF0");
            16: $write("ORI: 0b1010|0b0101=0xF");
            17: $write("ANDI: 0xFF&0x0F=0x0F");
            18: $write("SLLI: 1<<5=32");
            19: $write("SRLI: 128>>4=8  [NOTE: logical, zero-fills MSB]");
            20: $write("SRLI NOTE: 0x80000000>>1=0x40000000 (zero-fills MSB)");
            21: $write("SRAI: -16>>2=-4  [NOTE: msb-extends]");
            22: $write("SRAI NOTE: -16>>2=-4 (MSB=1 preserved, stays negative)");
            23: $write("SLTI: -5<0 (signed imm) => rd=1");
            24: $write("SLTIU: 3<10 (unsigned imm) => rd=1");
            25: $write("SLTIU NOTE: imm treated as unsigned; x<0xFFFFFFFF always true for positive x");
            26: $write("SW: store word 0x7FF to memory");
            27: $write("LW: load word 0xFFFFFFFF (full 32-bit, no extension)");
            28: $write("SH: store halfword -100 (lower 16 bits of rs2)");
            29: $write("LH: load halfword with sign-extension");
            30: $write("LHU: load halfword zero-extended  [NOTE: zero-extends, NOT sign-extends]");
            31: $write("LHU NOTE: lhu 0xFFFF=65535, not -1 (lh would give -1)");
            32: $write("SB: store byte -5 (lower 8 bits of rs2)");
            33: $write("LB: load byte with sign-extension");
            34: $write("LBU: load byte zero-extended  [NOTE: zero-extends, NOT sign-extends]");
            35: $write("LBU NOTE: lbu 0xFB=251, not -5 (lb would give -5)");
            36: $write("BEQ: rs1==rs2 => branch taken");
            37: $write("BNE: rs1!=rs2 => branch taken");
            38: $write("BLT: -1<1 (signed) => branch taken");
            39: $write("BGE: 5>=3 (signed) => branch taken");
            40: $write("BLTU: 1<0xFFF (unsigned) => branch taken  [NOTE: zero-extends]");
            41: $write("BLTU NOTE: 1 <u 0xFFFFFFFF(=-1 signed) => taken (treats operands as unsigned)");
            42: $write("BGEU: 0xFFF>=1 (unsigned) => branch taken  [NOTE: zero-extends]");
            43: $write("BGEU NOTE: 0xFFFFFFFF(=-1 signed) >=u 1 => taken (unsigned comparison)");
            44: $write("JAL: rd=PC+4, unconditional jump over fail++");
            45: $write("JALR: rd=PC+4, jump to rs1+imm, skip fail++");
            46: $write("LUI: rd = imm<<12  (upper 20 bits, lower 12 zeroed)");
            47: $write("AUIPC: rd = PC + (imm<<12)");
            48: $write("SB offset 1: store byte to addr[1:0]=01, read back with LBU");
            49: $write("SB offset 2: store byte to addr[1:0]=10, read back with LBU");
            50: $write("LB offset 1: sign-extend byte at addr[1:0]=01");
            51: $write("SH offset 2: store half to addr[1:0]=10, read back with LHU");
            52: $write("LH offset 2: sign-extend half at addr[1:0]=10");
            default: $write("unknown");
        endcase
        end
    endtask

    reg [31:0] prev_pass;
    reg [31:0] prev_fail;

    initial begin
        prev_pass = 0;
        prev_fail  = 0;
    end

    always @(posedge clk) begin : monitor_block
        reg [31:0] cp, cf, tnum;
        cp = dut.core.regfile.registers[28];
        cf = dut.core.regfile.registers[29];
        if (cp !== prev_pass || cf !== prev_fail) begin
            tnum = cp + cf;
            if (cf > prev_fail) begin
                $write("[FAIL] Test %2d: ", tnum);
                print_test_name(tnum);
                $write("\n");
            end else begin
                $write("[PASS] Test %2d: ", tnum);
                print_test_name(tnum);
                $write("\n");
            end
            prev_pass = cp;
            prev_fail  = cf;
        end
    end

    task load_program;
        integer i;
        begin
            for (i = 0; i < MEM_WORDS; i = i + 1)
                mem[i] = 32'h0000_0013;
            mem[  0] = 32'h00F00513;  // Test 1: ADD: 15+10=25
            mem[  1] = 32'h00A00593;
            mem[  2] = 32'h00B50633;
            mem[  3] = 32'h01900693;
            mem[  4] = 32'h00D60463;
            mem[  5] = 32'h001E8E93;
            mem[  6] = 32'h001E0E13;
            mem[  7] = 32'h40B50633;  // Test 2: SUB: 15-10=5
            mem[  8] = 32'h00500693;
            mem[  9] = 32'h00D60463;
            mem[ 10] = 32'h001E8E93;
            mem[ 11] = 32'h001E0E13;
            mem[ 12] = 32'h00A00513;  // Test 3: XOR: 0xA^0xC=0x6
            mem[ 13] = 32'h00C00593;
            mem[ 14] = 32'h00B54633;
            mem[ 15] = 32'h00600693;
            mem[ 16] = 32'h00D60463;
            mem[ 17] = 32'h001E8E93;
            mem[ 18] = 32'h001E0E13;
            mem[ 19] = 32'h00B56633;  // Test 4: OR: 0xA|0xC=0xE
            mem[ 20] = 32'h00E00693;
            mem[ 21] = 32'h00D60463;
            mem[ 22] = 32'h001E8E93;
            mem[ 23] = 32'h001E0E13;
            mem[ 24] = 32'h00B57633;  // Test 5: AND: 0xA&0xC=0x8
            mem[ 25] = 32'h00800693;
            mem[ 26] = 32'h00D60463;
            mem[ 27] = 32'h001E8E93;
            mem[ 28] = 32'h001E0E13;
            mem[ 29] = 32'h00100513;  // Test 6: SLL: 1<<4=16
            mem[ 30] = 32'h00400593;
            mem[ 31] = 32'h00B51633;
            mem[ 32] = 32'h01000693;
            mem[ 33] = 32'h00D60463;
            mem[ 34] = 32'h001E8E93;
            mem[ 35] = 32'h001E0E13;
            mem[ 36] = 32'h04000513;  // Test 7: SRL: 64>>3=8  [NOTE: logical, zero-fills MSB]
            mem[ 37] = 32'h00300593;
            mem[ 38] = 32'h00B55633;
            mem[ 39] = 32'h00800693;
            mem[ 40] = 32'h00D60463;
            mem[ 41] = 32'h001E8E93;
            mem[ 42] = 32'h001E0E13;
            mem[ 43] = 32'h80000537;  // Test 8: SRL NOTE: 0x80000000>>1=0x40000000 (zero-fills, not 0xC0000000)
            mem[ 44] = 32'h00100593;
            mem[ 45] = 32'h00B55633;
            mem[ 46] = 32'h400006B7;
            mem[ 47] = 32'h00D60463;
            mem[ 48] = 32'h001E8E93;
            mem[ 49] = 32'h001E0E13;
            mem[ 50] = 32'hFF800513;  // Test 9: SRA: -8>>2=-2  [NOTE: msb-extends]
            mem[ 51] = 32'h00200593;
            mem[ 52] = 32'h40B55633;
            mem[ 53] = 32'hFFE00693;
            mem[ 54] = 32'h00D60463;
            mem[ 55] = 32'h001E8E93;
            mem[ 56] = 32'h001E0E13;
            mem[ 57] = 32'h00000593;  // Test 10: SRA NOTE: -8>>2=-2 (MSB=1 preserved, not zero-filled)
            mem[ 58] = 32'h00B627B3;
            mem[ 59] = 32'h00100693;
            mem[ 60] = 32'h00D78463;
            mem[ 61] = 32'h001E8E93;
            mem[ 62] = 32'h001E0E13;
            mem[ 63] = 32'hFFF00513;  // Test 11: SLT: -1<0 (signed) => rd=1
            mem[ 64] = 32'h00000593;
            mem[ 65] = 32'h00B52633;
            mem[ 66] = 32'h00100693;
            mem[ 67] = 32'h00D60463;
            mem[ 68] = 32'h001E8E93;
            mem[ 69] = 32'h001E0E13;
            mem[ 70] = 32'h00100513;  // Test 12: SLTU: 1<2 (unsigned) => rd=1
            mem[ 71] = 32'h00200593;
            mem[ 72] = 32'h00B53633;
            mem[ 73] = 32'h00100693;
            mem[ 74] = 32'h00D60463;
            mem[ 75] = 32'h001E8E93;
            mem[ 76] = 32'h001E0E13;
            mem[ 77] = 32'hFFF00513;  // Test 13: SLTU NOTE: -1(=0xFFFFFFFF) > 1 unsigned => rd=0 (zero-extends)
            mem[ 78] = 32'h00100593;
            mem[ 79] = 32'h00B53633;
            mem[ 80] = 32'h00060463;
            mem[ 81] = 32'h001E8E93;
            mem[ 82] = 32'h001E0E13;
            mem[ 83] = 32'h06400513;  // Test 14: ADDI: 100+(-3)=97
            mem[ 84] = 32'hFFD50613;
            mem[ 85] = 32'h06100693;
            mem[ 86] = 32'h00D60463;
            mem[ 87] = 32'h001E8E93;
            mem[ 88] = 32'h001E0E13;
            mem[ 89] = 32'h0FF00513;  // Test 15: XORI: 0xFF^0x0F=0xF0
            mem[ 90] = 32'h00F54613;
            mem[ 91] = 32'h0F000693;
            mem[ 92] = 32'h00D60463;
            mem[ 93] = 32'h001E8E93;
            mem[ 94] = 32'h001E0E13;
            mem[ 95] = 32'h00A00513;  // Test 16: ORI: 0b1010|0b0101=0xF
            mem[ 96] = 32'h00556613;
            mem[ 97] = 32'h00F00693;
            mem[ 98] = 32'h00D60463;
            mem[ 99] = 32'h001E8E93;
            mem[100] = 32'h001E0E13;
            mem[101] = 32'h0FF00513;  // Test 17: ANDI: 0xFF&0x0F=0x0F
            mem[102] = 32'h00F57613;
            mem[103] = 32'h00F00693;
            mem[104] = 32'h00D60463;
            mem[105] = 32'h001E8E93;
            mem[106] = 32'h001E0E13;
            mem[107] = 32'h00100513;  // Test 18: SLLI: 1<<5=32
            mem[108] = 32'h00551613;
            mem[109] = 32'h02000693;
            mem[110] = 32'h00D60463;
            mem[111] = 32'h001E8E93;
            mem[112] = 32'h001E0E13;
            mem[113] = 32'h08000513;  // Test 19: SRLI: 128>>4=8  [NOTE: logical, zero-fills MSB]
            mem[114] = 32'h00455613;
            mem[115] = 32'h00800693;
            mem[116] = 32'h00D60463;
            mem[117] = 32'h001E8E93;
            mem[118] = 32'h001E0E13;
            mem[119] = 32'h80000537;  // Test 20: SRLI NOTE: 0x80000000>>1=0x40000000 (zero-fills MSB)
            mem[120] = 32'h00155613;
            mem[121] = 32'h400006B7;
            mem[122] = 32'h00D60463;
            mem[123] = 32'h001E8E93;
            mem[124] = 32'h001E0E13;
            mem[125] = 32'hFF000513;  // Test 21: SRAI: -16>>2=-4  [NOTE: msb-extends]
            mem[126] = 32'h40255613;
            mem[127] = 32'hFFC00693;
            mem[128] = 32'h00D60463;
            mem[129] = 32'h001E8E93;
            mem[130] = 32'h001E0E13;
            mem[131] = 32'h00000593;  // Test 22: SRAI NOTE: -16>>2=-4 (MSB=1 preserved, stays negative)
            mem[132] = 32'h00B627B3;
            mem[133] = 32'h00100693;
            mem[134] = 32'h00D78463;
            mem[135] = 32'h001E8E93;
            mem[136] = 32'h001E0E13;
            mem[137] = 32'hFFB00513;  // Test 23: SLTI: -5<0 (signed imm) => rd=1
            mem[138] = 32'h00052613;
            mem[139] = 32'h00100693;
            mem[140] = 32'h00D60463;
            mem[141] = 32'h001E8E93;
            mem[142] = 32'h001E0E13;
            mem[143] = 32'h00300513;  // Test 24: SLTIU: 3<10 (unsigned imm) => rd=1
            mem[144] = 32'h00A53613;
            mem[145] = 32'h00100693;
            mem[146] = 32'h00D60463;
            mem[147] = 32'h001E8E93;
            mem[148] = 32'h001E0E13;
            mem[149] = 32'h02A00513;  // Test 25: SLTIU NOTE: imm treated as unsigned; x<0xFFFFFFFF always true for positive x
            mem[150] = 32'hFFF53613;
            mem[151] = 32'h00100693;
            mem[152] = 32'h00D60463;
            mem[153] = 32'h001E8E93;
            mem[154] = 32'h001E0E13;
            mem[155] = 32'h60000713;
            mem[156] = 32'h7FF00513;  // Test 26: SW: store word 0x7FF to memory
            mem[157] = 32'h00A72023;
            mem[158] = 32'h00072583;
            mem[159] = 32'h00B50463;
            mem[160] = 32'h001E8E93;
            mem[161] = 32'h001E0E13;
            mem[162] = 32'hFFF00513;  // Test 27: LW: load word 0xFFFFFFFF (full 32-bit, no extension)
            mem[163] = 32'h00A72023;
            mem[164] = 32'h00072603;
            mem[165] = 32'h00A60463;
            mem[166] = 32'h001E8E93;
            mem[167] = 32'h001E0E13;
            mem[168] = 32'hF9C00513;  // Test 28: SH: store halfword -100 (lower 16 bits of rs2)
            mem[169] = 32'h00A71223;
            mem[170] = 32'h00471583;
            mem[171] = 32'h00B50463;
            mem[172] = 32'h001E8E93;
            mem[173] = 32'h001E0E13;
            mem[174] = 32'h00471603;  // Test 29: LH: load halfword with sign-extension
            mem[175] = 32'hF9C00693;
            mem[176] = 32'h00D60463;
            mem[177] = 32'h001E8E93;
            mem[178] = 32'h001E0E13;
            mem[179] = 32'hFFF00513;  // Test 30: LHU: load halfword zero-extended  [NOTE: zero-extends, NOT sign-extends]
            mem[180] = 32'h00A71823;
            mem[181] = 32'h01075583;
            mem[182] = 32'hFFF00693;
            mem[183] = 32'h0106D693;
            mem[184] = 32'h00D58463;
            mem[185] = 32'h001E8E93;
            mem[186] = 32'h001E0E13;
            mem[187] = 32'h00000793;  // Test 31: LHU NOTE: lhu 0xFFFF=65535, not -1 (lh would give -1)
            mem[188] = 32'h00F5D833;
            mem[189] = 32'h00F5A833;
            mem[190] = 32'h00080463;
            mem[191] = 32'h001E8E93;
            mem[192] = 32'h001E0E13;
            mem[193] = 32'hFFB00513;  // Test 32: SB: store byte -5 (lower 8 bits of rs2)
            mem[194] = 32'h00A70423;
            mem[195] = 32'h00870583;
            mem[196] = 32'h00B50463;
            mem[197] = 32'h001E8E93;
            mem[198] = 32'h001E0E13;
            mem[199] = 32'h00870603;  // Test 33: LB: load byte with sign-extension
            mem[200] = 32'hFFB00693;
            mem[201] = 32'h00D60463;
            mem[202] = 32'h001E8E93;
            mem[203] = 32'h001E0E13;
            mem[204] = 32'h00874583;  // Test 34: LBU: load byte zero-extended  [NOTE: zero-extends, NOT sign-extends]
            mem[205] = 32'h0FB00693;
            mem[206] = 32'h00D58463;
            mem[207] = 32'h001E8E93;
            mem[208] = 32'h001E0E13;
            mem[209] = 32'h00000793;  // Test 35: LBU NOTE: lbu 0xFB=251, not -5 (lb would give -5)
            mem[210] = 32'h00F5A833;
            mem[211] = 32'h00080463;
            mem[212] = 32'h001E8E93;
            mem[213] = 32'h001E0E13;
            mem[214] = 32'h00700513;  // Test 36: BEQ: rs1==rs2 => branch taken
            mem[215] = 32'h00700593;
            mem[216] = 32'h00B50463;
            mem[217] = 32'h001E8E93;
            mem[218] = 32'h001E0E13;
            mem[219] = 32'h00700513;  // Test 37: BNE: rs1!=rs2 => branch taken
            mem[220] = 32'h00800593;
            mem[221] = 32'h00B51463;
            mem[222] = 32'h001E8E93;
            mem[223] = 32'h001E0E13;
            mem[224] = 32'hFFF00513;  // Test 38: BLT: -1<1 (signed) => branch taken
            mem[225] = 32'h00100593;
            mem[226] = 32'h00B54463;
            mem[227] = 32'h001E8E93;
            mem[228] = 32'h001E0E13;
            mem[229] = 32'h00500513;  // Test 39: BGE: 5>=3 (signed) => branch taken
            mem[230] = 32'h00300593;
            mem[231] = 32'h00B55463;
            mem[232] = 32'h001E8E93;
            mem[233] = 32'h001E0E13;
            mem[234] = 32'h00100513;  // Test 40: BLTU: 1<0xFFF (unsigned) => branch taken  [NOTE: zero-extends]
            mem[235] = 32'hFFF00593;
            mem[236] = 32'h00B56463;
            mem[237] = 32'h001E8E93;
            mem[238] = 32'h001E0E13;
            mem[239] = 32'h00100513;  // Test 41: BLTU NOTE: 1 <u 0xFFFFFFFF(=-1 signed) => taken (treats operands as unsigned)
            mem[240] = 32'hFFF00593;
            mem[241] = 32'h00B56463;
            mem[242] = 32'h001E8E93;
            mem[243] = 32'h001E0E13;
            mem[244] = 32'hFFF00513;  // Test 42: BGEU: 0xFFF>=1 (unsigned) => branch taken  [NOTE: zero-extends]
            mem[245] = 32'h00100593;
            mem[246] = 32'h00B57463;
            mem[247] = 32'h001E8E93;
            mem[248] = 32'h001E0E13;
            mem[249] = 32'hFFF00513;  // Test 43: BGEU NOTE: 0xFFFFFFFF(=-1 signed) >=u 1 => taken (unsigned comparison)
            mem[250] = 32'h00100593;
            mem[251] = 32'h00B57463;
            mem[252] = 32'h001E8E93;
            mem[253] = 32'h001E0E13;
            mem[254] = 32'h008000EF;  // Test 44: JAL: rd=PC+4, unconditional jump over fail++
            mem[255] = 32'h001E8E93;
            mem[256] = 32'h001E0E13;
            mem[257] = 32'h41000513;  // Test 45: JALR: rd=PC+4, jump to rs1+imm, skip fail++
            mem[258] = 32'h00050167;
            mem[259] = 32'h001E8E93;
            mem[260] = 32'h001E0E13;
            mem[261] = 32'h00001537;  // Test 46: LUI: rd = imm<<12  (upper 20 bits, lower 12 zeroed)
            mem[262] = 32'h00C55593;
            mem[263] = 32'h00100693;
            mem[264] = 32'h00D58463;
            mem[265] = 32'h001E8E93;
            mem[266] = 32'h001E0E13;
            mem[267] = 32'h00000517;  // Test 47: AUIPC: rd = PC + (imm<<12)
            mem[268] = 32'h42C00593;
            mem[269] = 32'h00B50463;
            mem[270] = 32'h001E8E93;
            mem[271] = 32'h001E0E13;
            mem[272] = 32'h04200513;  // Test 48: SB offset 1: store byte to addr[1:0]=01, read back with LBU
            mem[273] = 32'h00A700A3;
            mem[274] = 32'h00174583;
            mem[275] = 32'h00B50463;
            mem[276] = 32'h001E8E93;
            mem[277] = 32'h001E0E13;
            mem[278] = 32'h07E00513;  // Test 49: SB offset 2: store byte to addr[1:0]=10, read back with LBU
            mem[279] = 32'h00A70123;
            mem[280] = 32'h00274583;
            mem[281] = 32'h00B50463;
            mem[282] = 32'h001E8E93;
            mem[283] = 32'h001E0E13;
            mem[284] = 32'hFFB00513;  // Test 50: LB offset 1: sign-extend byte at addr[1:0]=01
            mem[285] = 32'h00A700A3;
            mem[286] = 32'h00170583;
            mem[287] = 32'h00B50463;
            mem[288] = 32'h001E8E93;
            mem[289] = 32'h001E0E13;
            mem[290] = 32'h1FF00513;  // Test 51: SH offset 2: store half to addr[1:0]=10, read back with LHU
            mem[291] = 32'h00A71123;
            mem[292] = 32'h00275583;
            mem[293] = 32'h00B50463;
            mem[294] = 32'h001E8E93;
            mem[295] = 32'h001E0E13;
            mem[296] = 32'hF9C00513;  // Test 52: LH offset 2: sign-extend half at addr[1:0]=10
            mem[297] = 32'h00A71123;
            mem[298] = 32'h00271583;
            mem[299] = 32'h00B50463;
            mem[300] = 32'h001E8E93;
            mem[301] = 32'h001E0E13;
            mem[302] = 32'h0000006F;
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_25125008_riscv);
        load_program();
        reset = 0;
        @(posedge clk); @(posedge clk);
        reset = 1;
        repeat (3000) @(posedge clk);

        $display("");
        $display("==============================================");
        $display("  PASS (x28) = %0d / 52", dut.core.regfile.registers[28]);
        $display("  FAIL (x29) = %0d",           dut.core.regfile.registers[29]);
        if (dut.core.regfile.registers[29] == 0 &&
            dut.core.regfile.registers[28] == 52)
            $display("  *** ALL 52 TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");
        $display("==============================================");
        $finish;
    end

    initial begin #5_000_000; $display("TIMEOUT"); $finish; end

endmodule
