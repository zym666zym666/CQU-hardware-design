// mycpu_top模块 - 顶层模块，包含CPU的主要逻辑和连接外部存储器（SRAM）的接口

module mycpu_top(
    input clk,                 // 时钟信号
    input resetn,             // 复位信号（低电平有效）
    input [5:0] ext_int,      // 外部中断信号
    
    // CPU指令SRAM接口
    output inst_sram_en,      // 指令SRAM使能信号
    output [3:0] inst_sram_wen, // 指令SRAM写使能
    output [31:0] inst_sram_addr, // 指令SRAM地址
    output [31:0] inst_sram_wdata, // 指令SRAM写数据
    input [31:0] inst_sram_rdata,  // 指令SRAM读数据
    
    // CPU数据SRAM接口
    output data_sram_en,      // 数据SRAM使能信号
    output [3:0] data_sram_wen,  // 数据SRAM写使能
    output [31:0] data_sram_addr, // 数据SRAM地址
    output [31:0] data_sram_wdata, // 数据SRAM写数据
    input [31:0] data_sram_rdata, // 数据SRAM读数据

    // 调试输出
    output [31:0] debug_wb_pc,     // 写回阶段PC值
    output [3:0] debug_wb_rf_wen,  // 写回阶段寄存器写使能
    output [4:0] debug_wb_rf_wnum, // 写回阶段寄存器写入编号
    output [31:0] debug_wb_rf_wdata // 写回阶段寄存器写入数据
);

    // 内部信号
    wire [31:0] pc;              // 程序计数器（PC）
    wire [31:0] instr;           // 取指阶段指令
    wire data_en;                // 数据使能信号
    wire [31:0] aluout, writedata, readdata;  // ALU输出、写数据、读数据
    wire [3:0] mem_wen;          // 存储器写使能信号
    
    // MMU信号
    wire [31:0] inst_vaddr;      // 指令虚拟地址
    wire [31:0] inst_paddr;      // 指令物理地址
    wire [31:0] data_vaddr;      // 数据虚拟地址
    wire [31:0] data_paddr;      // 数据物理地址
    
    // MIPS处理器实例
    mips mips(
        .clk(~clk),             // 时钟取反，保证DRAM和IRAM在同一时钟周期读取
        .rst(~resetn),          // 复位信号取反
        .ext_int(ext_int),      // 外部中断
        .pcF(pc),               // 程序计数器（PC）
        .instrF(instr),         // 取指阶段的指令
        .mem_enM(data_en),      // 数据使能信号
        .aluoutM(aluout),       // ALU计算结果
        .mem_write_dataM(writedata),  // 写数据
        .readdataM(readdata),   // 读数据
        .mem_wenM(mem_wen),     // 存储器写使能信号
        .debug_wb_pc(debug_wb_pc),   // 写回阶段PC
        .debug_wb_rf_wen(debug_wb_rf_wen), // 写回阶段寄存器写使能
        .debug_wb_rf_wnum(debug_wb_rf_wnum), // 写回阶段寄存器写入编号
        .debug_wb_rf_wdata(debug_wb_rf_wdata) // 写回阶段寄存器写入数据
    );
    
    // MMU模块实例，用于虚拟地址到物理地址的转换
    assign inst_vaddr = pc;        // 指令虚拟地址等于PC
    assign data_vaddr = aluout;    // 数据虚拟地址等于ALU输出
    mmu mmu(
        .inst_vaddr(inst_vaddr),    // 输入：指令虚拟地址
        .inst_paddr(inst_paddr),    // 输出：指令物理地址
        .data_vaddr(data_vaddr),    // 输入：数据虚拟地址
        .data_paddr(data_paddr)     // 输出：数据物理地址
    );

    // 指令SRAM控制信号分配
    assign inst_sram_en = 1'b1;           // 永远使能指令SRAM
    assign inst_sram_wen = 4'b0;          // 指令SRAM写使能无效
    assign inst_sram_addr = inst_paddr;   // 指令地址为物理地址
    assign inst_sram_wdata = 32'b0;       // 指令SRAM写数据无效
    assign instr = inst_sram_rdata;       // 从SRAM读取指令
    
    // 数据SRAM控制信号分配
    assign data_sram_en = data_en;           // 启用数据SRAM（根据ALU输出决定）
    assign data_sram_wen = mem_wen;          // 数据SRAM写使能信号
    assign data_sram_addr = data_paddr;      // 数据地址为物理地址
    assign data_sram_wdata = writedata;     // 写数据为ALU计算结果
    assign readdata = data_sram_rdata;      // 读取数据来自数据SRAM

    // 指令解码模块
    instdec instdec(
        .instr(instr)             // 输入：指令
    );

endmodule
