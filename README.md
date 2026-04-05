# rv32i-alu-verilog
A 32-bit ALU implementation for the RISC-V RV32I ISA, designed in Verilog. Supports arithmetic, logical, shift, and branch operations with flag generation (zero, carry, overflow, negative). Built for integration in a single-cycle processor datapath.
# RV32I ALU Design (Verilog)

A 32-bit Arithmetic Logic Unit (ALU) implementation for the RISC-V RV32I instruction set, written in Verilog HDL. This module is designed as part of a single-cycle processor datapath and supports a wide range of arithmetic, logical, shift, and branch operations.

---

##  Features

- 32-bit ALU compliant with RISC-V RV32I ISA
- Supports arithmetic operations: ADD, SUB
- Logical operations: AND, OR, XOR
- Shift operations: SLL, SRL, SRA
- Comparison operations: SLT (signed), SLTU (unsigned)
- Branch condition evaluation: BEQ, BNE, BLT, BGE, BLTU
- Flag generation:
  - Zero flag
  - Carry-out flag
  - Overflow flag
  - Negative flag

---

##  Design Overview

This ALU is a **combinational logic module** that performs operations based on a 4-bit control signal (`alu_op`). It takes two 32-bit inputs (`operand_a` and `operand_b`) and produces a 32-bit result along with status flags.

### Key Components:

- **Adder/Subtractor Unit**  
  Uses a 33-bit extension to detect carry and overflow efficiently.

- **Shift Unit**  
  Performs logical and arithmetic shifts using the lower 5 bits of the operand.

- **Comparator Logic**  
  Supports both signed and unsigned comparisons.

- **Branch Logic Integration**  
  Branch conditions are evaluated inside the ALU, simplifying processor control logic.

---

##  ALU Operation Encoding

| ALU_OP | Operation | Description |
|--------|----------|-------------|
| 0000 | ADD  | A + B |
| 0001 | SUB  | A - B |
| 0010 | AND  | A & B |
| 0011 | OR   | A \| B |
| 0100 | XOR  | A ^ B |
| 0101 | SLL  | A << B[4:0] |
| 0110 | SRL  | A >> B[4:0] |
| 0111 | SRA  | A >>> B[4:0] |
| 1000 | SLT  | Signed comparison |
| 1001 | SLTU | Unsigned comparison |
| 1010 | LUI  | Pass B |
| 1011 | BEQ  | A == B |
| 1100 | BNE  | A != B |
| 1101 | BLT  | A < B (signed) |
| 1110 | BGE  | A ≥ B (signed) |
| 1111 | BLTU | A < B (unsigned) |

---

##  Flags Description

- **Zero**: Set when result is 0  
- **Carry-out**: Indicates unsigned overflow in addition/subtraction  
- **Overflow**: Indicates signed overflow  
- **Negative**: Reflects the sign bit of the result  

---

##  Usage

This ALU module can be integrated into:
- Single-cycle RISC-V processors  
- Multi-cycle CPU designs  
- FPGA-based processor implementations  

---

##  Applications

- Processor datapath design  
- Computer architecture learning  
- RTL design and verification practice  
- FPGA prototyping  

---

##  Tools

- Verilog HDL
- Simulation tools (e.g., Icarus Verilog, ModelSim, Vivado)

---

