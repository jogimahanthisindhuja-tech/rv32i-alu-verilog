
//  RISC-V RV32I ALU
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

   
    // ALU operation encoding
    
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

  
    // Internal wires
    
    wire [31:0] add_result;
    wire [31:0] sub_result;
    wire [32:0] add_ext;    // 33-bit for carry detection
    wire [32:0] sub_ext;
    wire [ 4:0] shamt;

    // Signed interpretations
    wire signed [31:0] signed_a = $signed(operand_a);
    wire signed [31:0] signed_b = $signed(operand_b);

  
    // Adder / subtractor  (shared hardware)
    
    assign add_ext   = {1'b0, operand_a} + {1'b0, operand_b};
    assign sub_ext   = {1'b0, operand_a} - {1'b0, operand_b};
    assign add_result = add_ext[31:0];
    assign sub_result = sub_ext[31:0];

    // Shift amount (lower 5 bits of operand_b per RISC-V spec)
    assign shamt = operand_b[4:0];

  
    // Flag generation
   
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

   
    // Main ALU combinational block
    
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


// ============================================================
//  **Testbench**  — 


`ifdef SIMULATION

module riscv_alu_tb;

    reg  [31:0] a, b;
    reg  [ 3:0] op;
    wire [31:0] result;
    wire        zero, overflow, carry_out, negative;

    // Instantiate DUT
    riscv_alu dut (
        .operand_a (a),
        .operand_b (b),
        .alu_op    (op),
        .result    (result),
        .zero      (zero),
        .overflow  (overflow),
        .carry_out (carry_out),
        .negative  (negative)
    );

    // Helper task
    task check;
        input [63:0] expected;
        input [31:0] mask;
        input [127:0] name;
        begin
            if ((result & mask) !== (expected[31:0] & mask)) begin
                $display("FAIL  %-8s  A=%08h B=%08h op=%b | got=%08h exp=%08h",
                         name, a, b, op, result, expected[31:0]);
            end else begin
                $display("PASS  %-8s  A=%08h B=%08h | result=%08h  z=%b ov=%b cy=%b ng=%b",
                         name, a, b, result, zero, overflow, carry_out, negative);
            end
        end
    endtask

    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, riscv_alu_tb);

        $display("\n========== RISC-V ALU Testbench ==========");

        // --- ADD ---
        a = 32'd15;  b = 32'd10;  op = 4'b0000;  #10;
        check(32'd25, 32'hFFFFFFFF, "ADD");

        // ADD overflow (positive + positive = negative)
        a = 32'h7FFFFFFF; b = 32'h00000001; op = 4'b0000; #10;
        check(32'h80000000, 32'hFFFFFFFF, "ADD_OVF");

        // --- SUB ---
        a = 32'd20;  b = 32'd7;   op = 4'b0001;  #10;
        check(32'd13, 32'hFFFFFFFF, "SUB");

        // SUB resulting in zero
        a = 32'd42;  b = 32'd42;  op = 4'b0001;  #10;
        check(32'd0, 32'hFFFFFFFF, "SUB_ZERO");

        // --- AND ---
        a = 32'hFF00FF00; b = 32'h0F0F0F0F; op = 4'b0010; #10;
        check(32'h0F000F00, 32'hFFFFFFFF, "AND");

        // --- OR ---
        a = 32'hF0F0F0F0; b = 32'h0F0F0F0F; op = 4'b0011; #10;
        check(32'hFFFFFFFF, 32'hFFFFFFFF, "OR");

        // --- XOR ---
        a = 32'hAAAAAAAA; b = 32'h55555555; op = 4'b0100; #10;
        check(32'hFFFFFFFF, 32'hFFFFFFFF, "XOR");

        // --- SLL ---
        a = 32'h00000001; b = 32'd4; op = 4'b0101; #10;
        check(32'h00000010, 32'hFFFFFFFF, "SLL");

        // --- SRL ---
        a = 32'h80000000; b = 32'd1; op = 4'b0110; #10;
        check(32'h40000000, 32'hFFFFFFFF, "SRL");

        // --- SRA ---
        a = 32'h80000000; b = 32'd1; op = 4'b0111; #10;
        check(32'hC0000000, 32'hFFFFFFFF, "SRA");

        // --- SLT (signed) ---
        a = 32'hFFFFFFF0; b = 32'h00000001; op = 4'b1000; #10;  // -16 < 1
        check(32'd1, 32'hFFFFFFFF, "SLT_T");

        a = 32'h00000001; b = 32'hFFFFFFF0; op = 4'b1000; #10;  // 1 < -16 false
        check(32'd0, 32'hFFFFFFFF, "SLT_F");

        // --- SLTU (unsigned) ---
        a = 32'h00000001; b = 32'hFFFFFFF0; op = 4'b1001; #10;  // 1 < big → true
        check(32'd1, 32'hFFFFFFFF, "SLTU_T");

        // --- LUI pass-through ---
        a = 32'h12345678; b = 32'hABCDE000; op = 4'b1010; #10;
        check(32'hABCDE000, 32'hFFFFFFFF, "LUI");

        // --- Branch: BEQ ---
        a = 32'd7; b = 32'd7; op = 4'b1011; #10;
        if (zero) $display("PASS  BEQ_T    zero asserted correctly");
        else      $display("FAIL  BEQ_T    zero should be 1");

        a = 32'd7; b = 32'd8; op = 4'b1011; #10;
        if (!zero) $display("PASS  BEQ_F    zero de-asserted correctly");
        else       $display("FAIL  BEQ_F    zero should be 0");

        // --- Branch: BLT ---
        a = 32'hFFFFFFF0; b = 32'd1; op = 4'b1101; #10;  // -16 < 1 → branch taken
        if (zero) $display("PASS  BLT_T    zero asserted correctly");
        else      $display("FAIL  BLT_T    zero should be 1");

        $display("==========================================\n");
        $finish;
    end

endmodule

`endif  // SIMULATION
