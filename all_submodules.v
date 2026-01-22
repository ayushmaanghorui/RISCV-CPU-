
// instr_mem.v - instruction memory

module instr_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 512) (
    input       [ADDR_WIDTH-1:0] instr_addr,
    output      [DATA_WIDTH-1:0] instr
);

// array of 64 32-bit words or instructions
reg [DATA_WIDTH-1:0] instr_ram [0:MEM_SIZE-1];

initial begin
    //$readmemh("rv32i_book.hex", instr_ram);
     $readmemh("rv32i_test.hex", instr_ram);
end

// word-aligned memory access
// combinational read logic
assign instr = instr_ram[instr_addr[31:2]];

endmodule

// data_mem.v - data memory
module data_mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_SIZE   = 64
)(
    input                     clk,
    input                     wr_en,
    input       [2:0]         funct3,
    input       [ADDR_WIDTH-1:0] wr_addr,
    input       [ADDR_WIDTH-1:0] wr_data,
    output reg  [DATA_WIDTH-1:0] rd_data_mem
);

    // Memory array: 64 words of 32 bits
    reg [DATA_WIDTH-1:0] data_ram [0:MEM_SIZE-1];

    // Word address extraction (no % operator)
    // Since MEM_SIZE = 64, only the lower 6 bits are needed
    wire [5:0] word_addr = wr_addr[7:2];

    // ---------- WRITE LOGIC (Synchronous) ----------
    always @(posedge clk) begin
        if (wr_en) begin
            case (funct3)
                3'b000: begin // SB
                    case (wr_addr[1:0])
                        2'b00: data_ram[word_addr][7:0]   <= wr_data[7:0];
                        2'b01: data_ram[word_addr][15:8]  <= wr_data[7:0];
                        2'b10: data_ram[word_addr][23:16] <= wr_data[7:0];
                        2'b11: data_ram[word_addr][31:24] <= wr_data[7:0];
                    endcase
                end

                3'b001: begin // SH
                    if (wr_addr[1])
                        data_ram[word_addr][31:16] <= wr_data[15:0];
                    else
                        data_ram[word_addr][15:0]  <= wr_data[15:0];
                end

                3'b010: data_ram[word_addr] <= wr_data; // SW
            endcase
        end
    end

    // ---------- READ LOGIC (Combinational) ----------
    wire [31:0] word_data = data_ram[word_addr];  // single BRAM read

    always @(*) begin
        case (funct3)
            3'b000: begin // LB
                case (wr_addr[1:0])
                    2'b00: rd_data_mem = {{24{word_data[7]}},  word_data[7:0]};
                    2'b01: rd_data_mem = {{24{word_data[15]}}, word_data[15:8]};
                    2'b10: rd_data_mem = {{24{word_data[23]}}, word_data[23:16]};
                    2'b11: rd_data_mem = {{24{word_data[31]}}, word_data[31:24]};
                endcase
            end

            3'b001: begin // LH
                if (wr_addr[1])
                    rd_data_mem = {{16{word_data[31]}}, word_data[31:16]};
                else
                    rd_data_mem = {{16{word_data[15]}}, word_data[15:0]};
            end

            3'b010: rd_data_mem = word_data; // LW

            3'b100: begin // LBU
                case (wr_addr[1:0])
                    2'b00: rd_data_mem = {24'b0, word_data[7:0]};
                    2'b01: rd_data_mem = {24'b0, word_data[15:8]};
                    2'b10: rd_data_mem = {24'b0, word_data[23:16]};
                    2'b11: rd_data_mem = {24'b0, word_data[31:24]};
                endcase
            end

            3'b101: begin // LHU
                if (wr_addr[1])
                    rd_data_mem = {16'b0, word_data[31:16]};
                else
                    rd_data_mem = {16'b0, word_data[15:0]};
            end

            default: rd_data_mem = 32'b0;
        endcase
    end

// reset_ff.v - 8-bit resettable D flip-flop

module reset_ff #(parameter WIDTH = 8) (
    input       clk, rst,
    input       [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);

always @(posedge clk or posedge rst) begin
    if (rst) q <= 0;
    else     q <= d;
end

endmodule


// reg_file.v - register file for single-cycle RISC-V CPU
//              (with 32 registers, each of 32 bits)
//              having two read ports, one write port
//              write port is synchronous, read ports are combinational
//              register 0 is hardwired to 0

module reg_file #(parameter DATA_WIDTH = 32) (
    input       clk,
    input       wr_en,
    input       [4:0] rd_addr1, rd_addr2, wr_addr,
    input       [DATA_WIDTH-1:0] wr_data,
    output      [DATA_WIDTH-1:0] rd_data1, rd_data2
);

reg [DATA_WIDTH-1:0] reg_file_arr [0:31];

integer i;
initial begin
    for (i = 0; i < 32; i = i + 1) begin
        reg_file_arr[i] = 0;
    end
end

// register file write logic (synchronous)
always @(posedge clk) begin
    if (wr_en) reg_file_arr[wr_addr] <= wr_data;
end

// register file read logic (combinational)
assign rd_data1 = ( rd_addr1 != 0 ) ? reg_file_arr[rd_addr1] : 0;
assign rd_data2 = ( rd_addr2 != 0 ) ? reg_file_arr[rd_addr2] : 0;

endmodule


// mux4.v - logic for 4-to-1 multiplexer

module mux4 #(parameter WIDTH = 8) (
    input       [WIDTH-1:0] d0, d1, d2, d3,
    input       [1:0] sel,
    output      [WIDTH-1:0] y
);

assign y = sel[1] ? (sel[0] ? d3 : d2) : (sel[0] ? d1 : d0);

endmodule


// mux3.v - logic for 3-to-1 multiplexer

module mux3 #(parameter WIDTH = 8) (
    input       [WIDTH-1:0] d0, d1, d2,
    input       [1:0] sel,
    output      [WIDTH-1:0] y
);

assign y = sel[1] ? d2: (sel[0] ? d1 : d0);

endmodule


// mux2.v - logic for 2-to-1 multiplexer

module mux2 #(parameter WIDTH = 8) (
    input       [WIDTH-1:0] d0, d1,
    input       sel,
    output      [WIDTH-1:0] y
);

assign y = sel ? d1 : d0;

endmodule


// main_decoder.v - logic for main decoder


module main_decoder (
    input  [6:0] op,
    input  [2:0] funct3,
    input        Zero, ALUR31,
    output reg [1:0] ResultSrc,
	 output reg       MemWrite, Branch, ALUSrc, RegWrite, Jump, jalr,
	 output reg [1:0] ImmSrc,
    output reg [1:0] ALUOp
    
);

always @(*) begin
    // Default (NOP-like)
    RegWrite = 0;
    ImmSrc   = 2'b00;
    ALUSrc   = 0;
    MemWrite = 0;
    ResultSrc= 2'b00;
    ALUOp    = 2'b00;
    Jump     = 0;
    jalr     = 0;
    Branch   = 0;

    casez(op)
        7'b0000011: begin  // lw
            RegWrite = 1;
            ALUSrc   = 1;
            ResultSrc= 2'b01;
        end

        7'b0100011: begin  // sw
            ImmSrc   = 2'b01;
            ALUSrc   = 1;
            MemWrite = 1;
        end

        7'b0110011: begin  // R-type
            RegWrite = 1;
            ALUOp    = 2'b10;
        end

        7'b1100011: begin  // branch group
            ImmSrc   = 2'b10;
            ALUOp    = 2'b01;
            case(funct3)
                3'b000: Branch =  Zero;    // beq
                3'b001: Branch = !Zero;    // bne
                3'b100: Branch =  ALUR31;  // blt
                3'b101: Branch = !ALUR31;  // bge
                3'b110: Branch =  ALUR31;  // bltu
                3'b111: Branch = !ALUR31;  // bgeu
                default: Branch = 1'b0;
            endcase
        end

        7'b0010011: begin  // I-type ALU
            RegWrite = 1;
            ALUSrc   = 1;
            ALUOp    = 2'b10;
        end

        7'b1101111: begin  // jal
            RegWrite = 1;
            ResultSrc= 2'b10;
            Jump     = 1;
        end

        7'b1100111: begin  // jalr
            RegWrite = 1;
            ALUSrc   = 1;
            ResultSrc= 2'b10;
            jalr     = 1;
        end

        7'b0?10111: begin  // lui
            RegWrite = 1;
            ResultSrc= 2'b11;
        end
    endcase
end

endmodule

// imm_extend.v - logic for sign extension
module imm_extend (
    input  [31:7]     instr,
    input  [ 1:0]     immsrc,
    output reg [31:0] immext
);

always @(*) begin
    case(immsrc)
        // I−type
        2'b00:   immext = {{20{instr[31]}}, instr[31:20]};
        // S−type (stores)
        2'b01:   immext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        // B−type (branches)
        2'b10:   immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
        // J−type (jal)
        2'b11:   immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
        default: immext = 32'bx; // undefined
    endcase
end

endmodule

// datapath.v
module datapath (
    input         clk, reset,
    input [1:0]   ResultSrc,
    input         PCSrc, ALUSrc,
    input         RegWrite,
    input [1:0]   ImmSrc,
    input [3:0]   ALUControl,
    input         jalr,
    output        Zero,ALUR31,  
    output [31:0] PC,
    input  [31:0] Instr,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result
);

wire [31:0] PCNext,PCjalr,PCPlus4, PCTarget,auipc,lauipc;
wire [31:0] ImmExt, SrcA, SrcB, WriteData, ALUResult;

// next PC logic
mux2 #(32)     pcmux(PCPlus4, PCTarget, PCSrc, PCNext);
mux2 #(32)     jalrmux(PCNext,ALUResult,jalr,PCjalr);

reset_ff #(32) pcreg(clk, reset, PCNext, PC);
adder          pcadd4(PC, 32'd4, PCPlus4);
adder          pcaddbranch(PC, ImmExt, PCTarget);


// register file logic
reg_file       rf (clk, RegWrite, Instr[19:15], Instr[24:20], Instr[11:7], Result, SrcA, WriteData);
imm_extend     ext (Instr[31:7], ImmSrc, ImmExt);

// ALU logic
mux2 #(32)     srcbmux(WriteData, ImmExt, ALUSrc, SrcB);
alu            alu (SrcA, SrcB, ALUControl, ALUResult, Zero);
adder #(32)    auipcadder ({Instr[31:12],12'b0},PC ,auipc);
mux2 #(32)      lauipcmux(auipc,  {Instr[31:12],12'b0},Instr[5],lauipc);
//result source 
mux4 #(32)     resultmux(ALUResult, ReadData, PCPlus4,lauipc, ResultSrc, Result);

assign ALUR31 =ALUResult[31];
assign Mem_WrData = WriteData;
assign Mem_WrAddr = ALUResult;

endmodule


// controller.v - controller for RISC-V CPU

module controller (
    input [6:0]  op,
    input [2:0]  funct3,
    input        funct7b5,
    input        Zero,ALUR31,
    output       [1:0] ResultSrc,
    output       MemWrite,
    output       PCSrc, ALUSrc,
    output       RegWrite, Jump,jalr,
    output [1:0] ImmSrc,
    output [3:0] ALUControl
);

wire [1:0] ALUOp;
wire       Branch;

main_decoder    md (op,funct3,Zero,ALUR31, ResultSrc, MemWrite, Branch,
                    ALUSrc, RegWrite, Jump,jalr, ImmSrc, ALUOp);

alu_decoder     ad (op[5], funct3, funct7b5, ALUOp, ALUControl);

// for jump and branch
assign PCSrc = Branch | Jump;

endmodule


// alu_decoder.v - logic for ALU decoder
module alu_decoder (
    input        opb5,       // bit 5 of opcode (as in your original)
    input [2:0]  funct3,
    input        funct7b5,   // bit 5 of funct7
    input [1:0]  ALUOp,
    output reg [3:0] ALUControl
);

    // Named constants for clarity (no behavior change)
    localparam [3:0]
        ADD  = 4'b0000,
        SUB  = 4'b0001,
        ANDR = 4'b0010,
        ORR  = 4'b0011,
        SLL  = 4'b0100,
        SRL  = 4'b0101,
        SLT  = 4'b0110,
        SRA  = 4'b0111,
        XORR = 4'b1000,
        SLTU = 4'b1001;

    always @(*) begin
        // Follow original priority exactly:
        // ALUOp == 00 -> ADD
        // ALUOp == 01 -> SUB
        // otherwise -> decode by funct3 and funct7b5/opb5 exactly as original
        if (ALUOp == 2'b00) begin
            ALUControl = ADD;
        end else if (ALUOp == 2'b01) begin
            ALUControl = SUB;
        end else begin
            case (funct3)
                3'b000: ALUControl = (funct7b5 & opb5) ? SUB : ADD;    // preserves (funct7b5 & opb5) check
                3'b001: ALUControl = SLL;
                3'b010: ALUControl = SLT;
                3'b011: ALUControl = SLTU;
                3'b100: ALUControl = XORR;
                3'b101: ALUControl = (!funct7b5) ? SRL : SRA;          // preserves !funct7b5 -> SRL else SRA
                3'b110: ALUControl = ORR;
                3'b111: ALUControl = ANDR;
                default: ALUControl = 4'bxxxx;                         // same 'unknown' default as original
            endcase
        end
    end

endmodule





// alu.v - ALU module

module alu #(parameter WIDTH = 32) (
    input       [WIDTH-1:0] a, b,       // operands
    input       [3:0] alu_ctrl,         // ALU control
    output reg  [WIDTH-1:0] alu_out,    // ALU output
    output      zero                    // zero flag
);

always @(a, b, alu_ctrl) begin
    case (alu_ctrl)
        4'b0000:  alu_out <= a + b;       // ADD
        4'b0001:  alu_out <= a + ~b + 1;  // SUB
        4'b0010:  alu_out <= a & b;       // AND
        4'b0011:  alu_out <= a | b;       // OR
		  4'b0100:  alu_out <= a << b[4:0];       // SLL
		  4'b0101:  alu_out <= a >> b[4:0];       // SRL
        4'b0110:  begin                   // SLT
                     if (a[31] != b[31]) alu_out <= a[31] ? 1 : 0;
                     else alu_out <= a < b ? 1 : 0;
                 end
        default: alu_out = 0;
		  4'b0111:  alu_out <= $signed(a) >>> b[4:0]; // SRA && SRAI 
		  4'b1000: alu_out <= a ^ b ; //XOR
		  4'b1001: alu_out <= (a < b) ? 1 : 0;    //SLTIU
    endcase
end

assign zero = (alu_out == 0) ? 1'b1 : 1'b0;

endmodule


// adder.v - logic for adder

module adder #(parameter WIDTH = 32) (
    input       [WIDTH-1:0] a, b,
    output      [WIDTH-1:0] sum
);

assign sum = a + b;

endmodule



endmodule
