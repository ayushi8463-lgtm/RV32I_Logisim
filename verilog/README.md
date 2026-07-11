# 25125008 — RV32I RISC-V Processor (Multi-Cycle Implementation)

Enrolment: 25125008  
Verilog Project — Design a single-cycle RISC-V processor (RV32I Base Integer Instruction Set)

---

## Files

| File | Description |
|------|-------------|
| `25125008_riscv.v` | Top-level module (interface + FSM + memory handling) |
| `ProcessorCore.v` | Main datapath (connects all modules, handles instruction/data flow) |
| `CoreControlUnit.v` | Combinational decoder — maps opcode/funct3/funct7 to all control signals |
| `ArithmeticLogicUnit.v` | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, LUI bypass |
| `ComparatorUnit.v` | Branch conditions and SLT/SLTU — signed and unsigned comparisons |
| `ImmediateSignExtend.v` | Generates immediates for different instruction types |
| `RegisterFile.v` | 32×32-bit register file, x0 hardwired to zero |
| `LoadStoreUnit.v` | Handles loads/stores, byte masking, and address alignment |
| `riscv_defs.vh` | Common constants |
| `tb_25125008_riscv.v` | Testbench (52 instruction tests) |

---

## Requirements

- **iVerilog** (Icarus Verilog) for compilation and simulation
- **vvp** (comes bundled with iVerilog)
- Optional: **GTKWave** to view waveforms

### Install iVerilog

| Platform | Command |
|----------|---------|
| macOS | `brew install icarus-verilog` |
| Ubuntu / Debian | `sudo apt install iverilog` |
| Windows | Download installer from http://bleyer.org/icarus/ |

---

## How to Run

All commands are run from **inside the `25125008_verilog` folder**.

### Step 1 — Open a terminal and navigate to the folder

```bash
cd path/to/25125008_verilog
```

For example, if it is in your Downloads folder:

```bash
cd ~/Downloads/25125008_verilog
```

### Step 2 — Compile

```bash
iverilog -g2005 -o ../sim \
  ArithmeticLogicUnit.v \
  ComparatorUnit.v \
  ImmediateSignExtend.v \
  RegisterFile.v \
  LoadStoreUnit.v \
  CoreControlUnit.v \
  ProcessorCore.v \
  25125008_riscv.v \
  tb_25125008_riscv.v
```

This produces an executable called `sim` one level above the folder.

### Step 3 — Run the simulation

```bash
vvp ../sim
```

### Expected output

```
[PASS] Test  1: ADD: 15+10=25
[PASS] Test  2: SUB: 15-10=5
[PASS] Test  3: XOR: 0xA^0xC=0x6
...
[PASS] Test 52: LH offset 2: sign-extend half at addr[1:0]=10

==============================================
  PASS (x28) = 52 / 52
  FAIL (x29) = 0
  *** ALL 52 TESTS PASSED ***
==============================================
```

### Step 4 — View waveforms (optional)

The simulation automatically writes a `dump.vcd` file. Open it with GTKWave:

```bash
gtkwave dump.vcd
```

### Alternative waveform viewer (macOS)

If GTKWave has compatibility issues on newer macOS versions, you can use:

```bash
surfer dump.vcd
```

---

## Testbench — 52 Tests

The testbench covers every instruction in the RV32I spec table, plus extra
tests for each instruction that has a **Note** in the spec (msb-extends /
zero-extends), and alignment tests for sub-word loads and stores.

| Tests | Instructions |
|-------|-------------|
| 1–10 | R-type: `add` `sub` `xor` `or` `and` `sll` `srl` `sra` `slt` `sltu` |
| 11–19 | I-ALU: `addi` `xori` `ori` `andi` `slli` `srli` `srai` `slti` `sltiu` |
| 20–27 | Memory: `sw` `lw` `sh` `lh` `lhu` `sb` `lb` `lbu` |
| 28–35 | Branch: `beq` `bne` `blt` `bge` `bltu` `bgeu` + note tests |
| 36–37 | Jump: `jal` `jalr` |
| 38–39 | Upper: `lui` `auipc` |
| 40–47 | Note tests: extra test per annotated instruction verifying msb-extend / zero-extend |
| 48–52 | Alignment tests: `sb`/`lb`/`lbu` at byte offset 1 and 2, `sh`/`lh`/`lhu` at offset 2 |

Each test prints `[PASS]` or `[FAIL]` immediately to the terminal as it completes.

---

## Top-Level Interface

```verilog
module riscv_processor (
    input  wire        clk,
    output reg  [31:0] mem_addr,    // address bus
    output reg  [31:0] mem_wdata,   // data to be written
    output reg  [ 3:0] mem_wmask,   // write mask (one bit per byte lane)
    input  wire [31:0] mem_rdata,   // data/instruction input
    output reg         mem_rstrb,   // assert to initiate a memory read
    input  wire        mem_rbusy,   // memory asserts when busy reading
    input  wire        mem_wbusy,   // memory asserts when busy writing
    input  wire        reset        // active-low: hold LOW to reset
);
```

### Reset behaviour

`reset` is **active-low** as specified in the project brief
("set to 0 to reset the processor").

---

## References and Inspiration

Used a research paper mainly to understand overall architecture and datapath design:

### Research Paper
**"Design and Implementation of 32-bit RISC-V Processor using Verilog"**  
Manjusha Rao P, Prabha Niranjan, Dileep Kumar M J  
NMAM Institute of Technology, Nitte (Deemed to be University)  
*2024 IEEE International Conference on Distributed Computing, VLSI, Electrical Circuits and Robotics (DISCOVER)*  
DOI: 10.1109/DISCOVER62353.2024.10750638

Used for: understanding the overall processor structure (PC, register file, ALU, control unit, data flow), why the ALU and comparator are kept separate for parallel branch handling, and how the Von Neumann memory model works.

---
