
`include "../defines2.vh"
`timescale 1ns / 1ps
module controller(
    // 输入端口：指令寄存器的输出，32位宽度
    input wire [31:0] instrD,

    // 控制信号输出端口
    output wire [4:0] alucontrolD, // ALU控制信号，决定ALU执行的操作
    output wire memtoregD, // 决定寄存器写入数据来源的信号
    output wire memwriteD, // 决定是否写入内存的信号
    output wire branchD, // 决定是否分支的信号
    output wire alusrcD, // 决定ALU操作数来源的信号
    output wire regwriteD, // 决定是否写入寄存器的信号
    output wire jumpD, // 决定是否跳转的信号
    output wire hilo_writeD, // 决定是否写入HI/LO寄存器的信号
    output wire jbralD, // 决定是否跳转到ALU结果的信号
    output wire jrD, // 决定是否执行寄存器跳转的信号
    output wire cp0_writeD, // 决定是否写入CP0寄存器的信号
    output wire is_invalidD, // 指令无效信号
    output wire [1:0] regdstD // 决定寄存器写入地址来源的信号
);

    // 定义内部信号
    wire [5:0] opD; // 操作码字段
    wire [5:0] functD; // 功能码字段
    wire [4:0] rsD; // 源寄存器字段
    wire [4:0] rtD; // 目标寄存器字段

    // 将指令的不同字段赋值给内部信号
    assign opD = instrD[31:26]; // 提取操作码字段
    assign functD = instrD[5:0]; // 提取功能码字段
    assign rsD = instrD[25:21]; // 提取源寄存器字段
    assign rtD = instrD[20:16]; // 提取目标寄存器字段

    // 实例化主解码器模块
    maindec md(
        opD, // 操作码
        functD, // 功能码
        rsD, // 源寄存器
        rtD, // 目标寄存器
        memtoregD, // 决定寄存器写入数据来源的信号
        memwriteD, // 决定是否写入内存的信号
        branchD, // 决定是否分支的信号
        alusrcD, // 决定ALU操作数来源的信号
        regdstD, // 决定寄存器写入地址来源的信号
        regwriteD, // 决定是否写入寄存器的信号
        jumpD, // 决定是否跳转的信号
        hilo_writeD, // 决定是否写入HI/LO寄存器的信号
        jbralD, // 决定是否跳转到ALU结果的信号
        jrD, // 决定是否执行寄存器跳转的信号
        cp0_writeD, // 决定是否写入CP0寄存器的信号
        is_invalidD // 指令无效信号
    );

    // 实例化ALU解码器模块
    aludec ad(
        functD, // 功能码
        opD, // 操作码
        rsD, // 源寄存器
        rtD, // 目标寄存器
        alucontrolD // ALU控制信号
    );
endmodule