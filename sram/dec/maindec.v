`include "../defines2.vh"
`timescale 1ns / 1ps

module maindec(
    input wire[5:0] op,        // 操作码，指定指令类型
    input wire[5:0] funct,     // 功能码，进一步指定指令的行为（仅用于R类型指令）
    input wire[4:0] rs,        // 源寄存器 rs（仅在部分指令中使用）
    input wire[4:0] rt,        // 源寄存器 rt（仅在部分指令中使用）
    output wire memtoreg,      // 数据来自内存，还是ALU的结果
    output wire memwrite,      // 内存写使能
    output wire branch,        // 是否为分支指令
    output wire alusrc,        // ALU第二操作数来源（立即数或寄存器）
    output wire[1:0] regdst,   // 寄存器写入地址选择
    output wire regwrite,      // 是否写回寄存器
    output wire jump,          // 是否跳转指令
    output wire hilo_write,    // 是否写入HI/LO寄存器
    output wire jbral,         // 是否为跳转并链接（jal）
    output wire jr,            // 是否为跳转寄存器（jr）
    output wire cp0_write,     // 是否写入CP0寄存器
    output reg is_invalid      // 是否为无效指令（非法指令）
);

    reg[11:0] controls;        // 用于存储解码后的控制信号（12位）
    assign {regwrite, regdst, alusrc, branch, memwrite, memtoreg, jump, hilo_write, jbral, jr, cp0_write} = controls;

    always @(*) begin
        is_invalid <= 1'b0;    // 默认不为无效指令
        case (op)               // 根据操作码（op）选择指令类型并生成控制信号
            `R_TYPE:            // R类型指令
                case (funct)
                    `ADD, `ADDU, `SUB, `SUBU, `SLT, `SLTU, `AND, `NOR, `OR, `XOR, `SLLV, `SLL, `SRAV, `SRA, `SRLV, `SRL, `MFHI, `MFLO:
                        controls <= 12'b1_01_000000000;  // 普通R类型算术与逻辑操作
                    `DIV, `DIVU, `MULT, `MULTU, `MTHI, `MTLO:
                        controls <= 12'b0_00_000001000;  // 普通R类型算术与逻辑操作
                    `JR: 
                        controls <= 12'b0_00_000000010;  // 跳转寄存器指令
                    `JALR: 
                        controls <= 12'b1_01_000000110; // 跳转并链接指令
                    `BREAK, `SYSCALL: 
                        controls <= 12'b0_00_000000000; // 系统调用或中断指令
                    default:begin
                        controls <= 12'b000000000000;  // 非法指令
                        is_invalid <= 1'b1;
                    end
                endcase
            // I-type指令
            `ADDI, `ADDIU, `SLTI, `SLTIU, `ANDI, `LUI, `ORI, `XORI:
                controls <= 12'b1_00_100000000; // ALU操作，立即数操作
            `BEQ, `BNE, `BGTZ, `BLEZ: 
                controls <= 12'b0_00_010000000; // 条件跳转指令
            `REGIMM_INST:            // 特殊的REGIMM指令（如BGEZ、BLTZ等）
                case (rt)
                    `BGEZ, `BLTZ:
                        controls <= 12'b0_00_010000000; // 条件跳转指令
                    `BGEZAL, `BLTZAL:
                        controls <= 12'b1_10_010000100; // 条件跳转并链接指令
                    default:begin
                        controls <= 12'b000000000000;  // 非法指令
                        is_invalid <= 1'b1;
                    end
                endcase
            // 加载/存储指令
            `LB, `LBU, `LH, `LHU, `LW:
                controls <= 12'b1_00_100100000; // 加载指令
            `SB, `SH, `SW: 
                controls <= 12'b0_00_101000000; // 存储指令
            // J-type指令
            `J: 
                controls <= 12'b0_00_000010000; // 跳转指令
            `JAL: 
                controls <= 12'b1_10_000010100; // 跳转并链接指令
            // 异常处理指令（如MTC0、MFC0、ERET等）
            `SPECIAL3_INST:
                case(rs)
                    `MTC0: 
                        controls <= 12'b0_00_000000001; // 写CP0寄存器
                    `MFC0: 
                        controls <= 12'b1_00_000000000; // 读CP0寄存器
                    `ERET: 
                        controls <= 12'b0_00_000000000; // 异常返回
                    default:begin
                        controls <= 12'b000000000000;  // 非法指令
                        is_invalid <= 1'b1;
                    end
                endcase   
            6'b111111:              // 特殊操作
                case(funct)
                    6'b000000: 
                        controls <= 12'b1_01_000000000; // 其他特殊操作
                endcase  
            default: begin
                controls <= 12'b000000000000;  // 非法指令
                is_invalid <= 1'b1;  // 设置无效标志
            end
        endcase
    end
endmodule