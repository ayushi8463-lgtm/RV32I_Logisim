# RISC-V RV32I Processor (Logisim-evolution)

A multicycle RV32I RISC-V CPU built as a hierarchical schematic in [Logisim-evolution](https://github.com/logisim-evolution/) (project format v4.1.0).

## Overview

`riscv.circ` implements a multicycle datapath and control unit for the RV32I base integer instruction set. Instructions execute over several clock cycles through a finite-state machine with **fetch → execute → memory-wait → writeback** stages.

- **ISA coverage:** all RV32I base integer instructions, **except `ecall` and `ebreak`**
- **Reset:** the `reset` pin is **active-low** (`0` = reset, `1` = normal operation)
- **Top-level circuit:** `processor` (wires together every module below and adds the FSM/control glue logic)

## Opening the project

1. Install [Logisim-evolution](https://github.com/logisim-evolution/logisim-evolution) v4.1.0 or later.
2. Open `riscv.circ`.
3. Select the **`processor`** circuit from the left-hand circuit tree to see the complete CPU.
4. To load a program, open the **`instructionmem`** subcircuit and edit the ROM contents (right-click the ROM → *Edit Contents*, or *Load Image*).

## Circuit modules

| Circuit | Role |
|---|---|
| `processor` | Top-level CPU: wires all modules together, holds the FSM state register, PC/instruction latching, and byte-enable/mux glue logic for the multicycle control flow. |
| `corecontrolunit` | Main (single-cycle) control unit — decodes `opcode`, `func3`, and the funct7 bit-5 into ALU operation, immediate-format select, operand-mux selects, register-write enable/source, branch/comparator selects, and load/store type. |
| `alu` | 32-bit Arithmetic Logic Unit — takes operands `A`, `B` and a 4-bit op-select, outputs 32-bit result `D`. |
| `imm` | Immediate generator — decodes the 32-bit instruction word and a 3-bit format-select into the correctly sign-extended 32-bit immediate. |
| `regfile` | 32×32-bit register file — two read ports (`rsi1`, `rsi2`), one write port (`rdi`, write-enable `we`), clocked. |
| `comparatorunit` | Branch condition evaluator — compares two 32-bit operands per a 3-bit comparison-type select (eq/ne/lt/ltu/ge/geu, etc.) and outputs a 1-bit taken/not-taken result. |
| `loadstore` | Load/store data formatter — aligns/extends load data and generates the byte write-strobe for store data based on a 4-bit load/store type and 2-bit address offset. |
| `pccounter` | Program counter — holds `PC`, computes `PC+4`, and selects between `PC+4` and a branch/jump target based on `next_pc_sel`, with synchronous reset and write-enable. |
| `instructionmem` | Instruction ROM — word-addressed instruction memory (`addressinput` → `insout`). Edit here to load a program. |
| `datamem` | Data RAM — word-addressed memory with a 4-bit byte write mask and clocked write. |
| `writeback` | Write-back mux — selects the value written to the register file (ALU result, memory data, immediate, comparator result, or `PC+4`) via a 3-bit select. |

## Requirements

- Logisim-evolution v4.1.0+ (uses standard `#Wiring`, `#Gates`, `#Plexers`, `#Arithmetic`, `#Memory`, and `#Base` libraries only — no external/custom libraries required).
