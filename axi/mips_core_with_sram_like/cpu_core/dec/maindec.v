`include "../defines2.vh"
`timescale 1ns / 1ps


module maindec(
    input wire[5:0] op,           // 操作码
    input wire[5:0] funct,        // 功能码
    input wire[4:0] rs,           // 源寄存器 1
    input wire[4:0] rt,           // 源寄存器 2
    output wire memtoreg,         // 选择数据来源到寄存器
    output wire memwrite,         // 内存写使能
    output wire branch,           // 分支指令控制信号
    output wire alusrc,           // ALU 输入选择信号
    output wire[1:0] regdst,      // 寄存器目标选择
    output wire regwrite,         // 寄存器写使能
    output wire jump,             // 跳转指令控制信号
    output wire hilo_write,       // HI/LO 寄存器写使能
    output wire jbral,            // 跳转/链接指令控制
    output wire jr,               // 跳转寄存器指令控制
    output wire cp0_write,        // CP0 寄存器写使能
    output reg is_invalid,        // 无效指令标志
    output wire hilotoreg,        // HI/LO 数据写回到寄存器控制信号
    output wire cp0toreg,         // CP0 数据写回到寄存器控制信号
    output reg memread,           // 内存读使能
    output wire [1:0] mfhi_lo     // MFHI/MFLO 指令标志
);

    // 解码 HI/LO 数据传输指令 (MFHI, MFLO)
    assign hilotoreg = (op == 6'b000000) && (funct == 6'b010000 || funct == 6'b010010);
    
    // 解码 CP0 数据传输指令
    assign cp0toreg = ~(|(op ^ 6'b010000)) & ~(|(rs ^ 5'b00000));

    // 解码 MFHI 和 MFLO 指令
    wire mfhi, mflo;
    assign mfhi = !(op ^ `R_TYPE) & !(funct ^ `MFHI);
    assign mflo = !(op ^ `R_TYPE) & !(funct ^ `MFLO);
    assign mfhi_lo = {mfhi, mflo};

    // 控制信号寄存器
    reg[11:0] controls;
    assign {regwrite, regdst, alusrc, branch, memwrite, memtoreg, jump, hilo_write, jbral, jr, cp0_write} = controls;

    // 根据 op 和 funct 解码控制信号
    always @(*) begin
        memread <= 1'b0; 
        is_invalid <= 1'b0;
        case (op)
            `R_TYPE:  // R 类型指令
                case (funct)
                    `ADD, `ADDU, `SUB, `SUBU, `SLT, `SLTU, 
                    `AND, `NOR, `OR, `XOR, 
                    `SLLV, `SLL, `SRAV, `SRA, `SRLV, `SRL, 
                    `MFHI, `MFLO: controls <= 12'b1_01_000000000;  // 普通 R 类型指令
                    `DIV, `DIVU, `MULT, `MULTU, 
                    `MTHI, `MTLO: controls <= 12'b0_00_000001000;  // 除法、乘法、MTHI、MTLO
                    `JR: controls <= 12'b0_00_000000010;  // JR 指令
                    `JALR: controls <= 12'b1_01_000000110;  // JALR 指令
                    `BREAK, `SYSCALL: controls <= 12'b0_00_000000000;  // 异常指令
                    default:  begin
                        controls <= 12'b000000000000;
                        is_invalid <= 1'b1;
                    end
                endcase
            `ADDI, `ADDIU, `SLTI, `SLTIU, 
            `ANDI, `LUI, `ORI, `XORI: controls <= 12'b1_00_100000000;  // I 类型指令
            `BEQ, `BNE, `BGTZ, `BLEZ: controls <= 12'b0_00_010000000;  // 分支指令
            `REGIMM_INST:  // 特殊寄存器指令
                case (rt)
                    `BGEZ, `BLTZ: controls <= 12'b0_00_010000000;
                    `BGEZAL, `BLTZAL: controls <= 12'b1_10_010000100;
                    default: begin
                        controls <= 12'b000000000000;
                        is_invalid <= 1'b1;
                    end
                endcase
            `LB, `LBU, `LH, `LHU, `LW: begin
                controls <= 12'b1_00_100100000;
                memread <= 1'b1;  // 内存读操作
            end
            `SB, `SH, `SW: controls <= 12'b0_00_101000000;  // 内存写操作
            `J: controls <= 12'b0_00_000010000;  // J 指令
            `JAL: controls <= 12'b1_10_000010100;  // JAL 指令
            `SPECIAL3_INST:  // CP0 指令
                case (rs)
                    `MTC0: controls <= 12'b0_00_000000001;
                    `MFC0: controls <= 12'b1_00_000000000;
                    `ERET: controls <= 12'b0_00_000000000;
                    default: begin
                        controls <= 12'b000000000000;
                        is_invalid <= 1'b1;
                    end
                endcase
            6'b111111:
                case (funct)
                    6'b000000: controls <= 12'b1_01_000000000;
                endcase
            default: begin
                controls <= 12'b000000000000;
                is_invalid <= 1'b1;
            end
        endcase
    end
endmodule