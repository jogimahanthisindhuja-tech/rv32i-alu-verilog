
RISC-V RV32I ALU
//  Supports all RV32I ALU operations driven by a 4-bit opcode.
//
//  ALU_OP encoding (matches funct3 / funct7 decode in the CPU):
//    4'b0000  ADD   : result = A + B
//    4'b0001  SUB   : result = A - B
//    4'b0010  AND   : result = A & B
//    4'b0011  OR    : result = A | B
//    4'b0100  XOR   : result = A ^ B
//    4'b0101  SLL   : result = A << B[4:0]
//    4'b0110  SRL   : result = A >> B[4:0]         (logical)
//    4'b0111  SRA   : result = A >>> B[4:0]        (arithmetic)
//    4'b1000  SLT   : result = (signed A < signed B) ? 1 : 0
//    4'b1001  SLTU  : result = (A < B)             ? 1 : 0
//    4'b1010  LUI   : result = B  (pass-through for LUI / AUIPC)
//    4'b1011  BEQ   : zero flag only (A == B)
//    4'b1100  BNE   : zero flag only (A != B)
//    4'b1101  BLT   : zero flag only (signed A < B)
//    4'b1110  BGE   : zero flag only (signed A >= B)
//    4'b1111  BLTU/BGEU: zero flag only (unsigned compare)
//
//  Flags:
//    zero     — result == 32'h0  (used by branch logic)
//    overflow — signed overflow  (ADD / SUB)
//    carry    — unsigned carry   (ADD / SUB)
//    negative — result[31]
// ============================================================

module riscv_alu (
    input  wire [31:0] operand_a,    // rs1 / PC
    input  wire [31:0] operand_b,    // rs2 / immediate
    input  wire [ 3:0] alu_op,       // operation select

    output reg  [31:0] result,       // ALU output
    output wire        zero,         // result == 0
    output wire        overflow,     // signed overflow
    output wire        carry_out,    // unsigned carry
    output wire        negative      // result[31]
);

    // ----------------------------------------------------------
    // ALU operation encoding
    // ----------------------------------------------------------
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_LUI  = 4'b1010;
    localparam ALU_BEQ  = 4'b1011;
    localparam ALU_BNE  = 4'b1100;
    localparam ALU_BLT  = 4'b1101;
    localparam ALU_BGE  = 4'b1110;
    localparam ALU_BLTU = 4'b1111;

    // ----------------------------------------------------------
    // Internal wires
    // ----------------------------------------------------------
    wire [31:0] add_result;
    wire [31:0] sub_result;
    wire [32:0] add_ext;    // 33-bit for carry detection
    wire [32:0] sub_ext;
    wire [ 4:0] shamt;

    // Signed interpretations
    wire signed [31:0] signed_a = $signed(operand_a);
    wire signed [31:0] signed_b = $signed(operand_b);

    // ----------------------------------------------------------
    // Adder / subtractor  (shared hardware)
    // ----------------------------------------------------------
    assign add_ext   = {1'b0, operand_a} + {1'b0, operand_b};
    assign sub_ext   = {1'b0, operand_a} - {1'b0, operand_b};
    assign add_result = add_ext[31:0];
    assign sub_result = sub_ext[31:0];

    // Shift amount (lower 5 bits of operand_b per RISC-V spec)
    assign shamt = operand_b[4:0];

    // ----------------------------------------------------------
    // Flag generation
    // ----------------------------------------------------------
    // Carry: from adder or subtractor depending on operation
    assign carry_out = (alu_op == ALU_ADD) ? add_ext[32] :
                       (alu_op == ALU_SUB) ? sub_ext[32] : 1'b0;

    // Signed overflow for ADD: (+)+(+)=(-) or (-)+(-)=(+)
    // Signed overflow for SUB: (+)-(-)=(-) or (-)-(+)=(+)
    assign overflow =
        (alu_op == ALU_ADD) ?
            (~operand_a[31] & ~operand_b[31] &  add_result[31]) |
            ( operand_a[31] &  operand_b[31] & ~add_result[31]) :
        (alu_op == ALU_SUB) ?
            (~operand_a[31] &  operand_b[31] &  sub_result[31]) |
            ( operand_a[31] & ~operand_b[31] & ~sub_result[31]) :
        1'b0;

    assign negative = result[31];
    assign zero     = (result == 32'h0);

    // ----------------------------------------------------------
    // Main ALU combinational block
    // ----------------------------------------------------------
    always @(*) begin
        case (alu_op)
            ALU_ADD  : result = add_result;
            ALU_SUB  : result = sub_result;
            ALU_AND  : result = operand_a & operand_b;
            ALU_OR   : result = operand_a | operand_b;
            ALU_XOR  : result = operand_a ^ operand_b;
            ALU_SLL  : result = operand_a << shamt;
            ALU_SRL  : result = operand_a >> shamt;
            ALU_SRA  : result = $signed(operand_a) >>> shamt;
            ALU_SLT  : result = (signed_a < signed_b) ? 32'd1 : 32'd0;
            ALU_SLTU : result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            ALU_LUI  : result = operand_b;                     // pass-through

            // Branch comparisons — result feeds zero flag to branch unit
            ALU_BEQ  : result = (operand_a == operand_b) ? 32'd0 : 32'd1;
            ALU_BNE  : result = (operand_a != operand_b) ? 32'd0 : 32'd1;
            ALU_BLT  : result = (signed_a  <  signed_b)  ? 32'd0 : 32'd1;
            ALU_BGE  : result = (signed_a  >= signed_b)  ? 32'd0 : 32'd1;
            ALU_BLTU : result = (operand_a <  operand_b) ? 32'd0 : 32'd1;

            default  : result = 32'h0;
        endcase
    end

endmodule
