// 模块名称：mmu
// 功能：内存管理单元（MMU），负责将虚拟地址转换为物理地址，并决定是否绕过数据缓存（D-Cache）
// KSEG0 的内存地址会通过数据缓存（D-Cache）进行
module mmu (
    input wire  [31:0] inst_vaddr,  // 指令虚拟地址
    output wire [31:0] inst_paddr,  // 指令物理地址
    input wire  [31:0] data_vaddr,  // 数据虚拟地址
    output wire [31:0] data_paddr,  // 数据物理地址

    output wire no_dcache           // 是否绕过数据缓存（D-Cache）
);
    // 用于指示地址是否属于KSEG0或KSEG1段的信号
    wire inst_kseg0, inst_kseg1;
    wire data_kseg0, data_kseg1;

    // 判断指令虚拟地址是否属于KSEG0段（地址高位为100）
    assign inst_kseg0 = inst_vaddr[31:29] == 3'b100;
    // 判断指令虚拟地址是否属于KSEG1段（地址高位为101）
    assign inst_kseg1 = inst_vaddr[31:29] == 3'b101;
    // 判断数据虚拟地址是否属于KSEG0段（地址高位为100）
    assign data_kseg0 = data_vaddr[31:29] == 3'b100;
    // 判断数据虚拟地址是否属于KSEG1段（地址高位为101）
    assign data_kseg1 = data_vaddr[31:29] == 3'b101;

    // 如果指令地址属于KSEG0或KSEG1段，则将高位3位清零，得到物理地址
    assign inst_paddr = inst_kseg0 | inst_kseg1 ?
                        {3'b0, inst_vaddr[28:0]} : inst_vaddr;

    // 如果数据地址属于KSEG0或KSEG1段，则将高位3位清零，得到物理地址
    assign data_paddr = data_kseg0 | data_kseg1 ?
                        {3'b0, data_vaddr[28:0]} : data_vaddr;

    // 如果数据地址属于KSEG1段，则指示绕过数据缓存
    assign no_dcache = data_kseg1 ? 1'b1 : 1'b0;

endmodule