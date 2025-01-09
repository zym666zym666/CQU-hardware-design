`include "../defines2.vh"
`timescale 1ns / 1ps
module controller(
    input wire [31:0] instrD,  // 输入指令寄存器D阶段的指令

    output wire [4:0] alucontrolD,  // ALU控制信号
    output wire memtoregD, memwriteD, branchD, alusrcD, regwriteD, jumpD, hilo_writeD, jbralD, jrD, cp0_writeD, is_invalidD,  // 控制信号
    output wire hilotoregD, cp0toregD,  // HI/LO和CP0寄存器的控制信号
    output wire [1:0] regdstD,  // 目的寄存器选择信号
    output wire memread,  // 数据存储器的读信号
    output wire [1:0] mfhi_lo  // HI/LO寄存器的控制信号
);

    wire [5:0] opD;  // 操作码
    wire [5:0] functD;  // 功能码
    wire [4:0] rsD;  // 源寄存器地址
    wire [4:0] rtD;  // 目标寄存器地址

    assign opD = instrD[31:26];  // 提取操作码
    assign functD = instrD[5:0];  // 提取功能码
    assign rsD = instrD[25:21];  // 提取源寄存器地址
    assign rtD = instrD[20:16];  // 提取目标寄存器地址

    maindec md(
        opD, functD, rsD, rtD,  // 输入信号
        memtoregD, memwriteD, branchD, alusrcD, regdstD, regwriteD, jumpD, hilo_writeD, jbralD, jrD, cp0_writeD, is_invalidD, hilotoregD, cp0toregD, memread, mfhi_lo  // 输出信号
    );

    aludec ad(functD, opD, rsD, rtD, alucontrolD);  // ALU控制信号生成
endmodule