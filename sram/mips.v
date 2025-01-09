// MIPS处理器顶层模块
// 包括数据路径和控制逻辑，处理指令的取指、解码、执行、访存和写回等操作

`timescale 1ns / 1ps
`include "defines2.vh"

module mips(
    // 输入信号
    input wire clk,              // 时钟信号
    input wire rst,              // 复位信号
    input wire [5:0] ext_int,   // 外部中断信号
    input wire [31:0] instrF,   // 取指阶段的指令
    input wire [31:0] readdataM,// 存储器读数据

    // 输出信号
    output wire [31:0] pcF,     // 当前PC值
    output wire [31:0] aluoutM, // ALU计算结果
    output wire [31:0] mem_write_dataM, // 写入存储器的数据
    output wire mem_enM,        // 存储器使能信号
    output wire [3:0] mem_wenM, // 存储器写使能
    output wire [31:0] debug_wb_pc,     // 写回阶段的PC
    output wire [3:0] debug_wb_rf_wen,  // 寄存器写使能
    output wire [4:0] debug_wb_rf_wnum, // 寄存器写入编号
    output wire [31:0] debug_wb_rf_wdata // 寄存器写入数据
);

    // 控制信号
    wire [31:0] instrD;        // 解码阶段指令
    wire [4:0] alucontrolD;    // ALU控制信号
    wire [1:0] regdstD;        // 寄存器写入选择
    wire memtoregD, memwriteD, // 存储器控制信号
         branchD, alusrcD,    // 分支和ALU操作数选择
         regwriteD, jumpD,    // 寄存器写使能、跳转控制
         hilo_writeD, jbralD, // HI/LO寄存器、跳转控制
         jrD, cp0_writeD,     // 跳转寄存器、CP0写使能
         is_invalidD;         // 无效指令信号

    // 数据路径模块实例
    datapath datapath(
        clk, rst, ext_int, instrD,        // 输入：时钟、复位、外部中断、指令
        alucontrolD, memtoregD, memwriteD, branchD, // 控制信号
        alusrcD, regwriteD, jumpD,        // ALU操作数选择、寄存器写使能、跳转
        hilo_writeD, jbralD, jrD,         // HI/LO寄存器写使能、跳转控制
        cp0_writeD, is_invalidD,          // CP0写使能、无效指令
        regdstD,                          // 寄存器写入选择
        // 输出：PC、指令、ALU结果、存储器数据等
        pcF, instrF, aluoutM, mem_write_dataM,
        readdataM, mem_enM, mem_wenM,
        debug_wb_pc, debug_wb_rf_wen,
        debug_wb_rf_wnum, debug_wb_rf_wdata
    );

    // 控制模块实例
    controller controller(
        instrD,          // 输入：解码阶段指令
        alucontrolD, memtoregD, memwriteD, branchD, // 控制信号
        alusrcD, regwriteD, jumpD, hilo_writeD,   // 控制信号
        jbralD, jrD, cp0_writeD, is_invalidD,     // 控制信号
        regdstD          // 寄存器写入选择信号
    );

endmodule
