// MMU模块（内存管理单元）
// 负责将虚拟地址转换为物理地址，并判断是否需要经过数据缓存（DCACHE）

module mmu (
    input wire  [31:0] inst_vaddr,    // 输入：指令虚拟地址
    output wire [31:0] inst_paddr,    // 输出：指令物理地址
    input wire  [31:0] data_vaddr,    // 输入：数据虚拟地址
    output wire [31:0] data_paddr,    // 输出：数据物理地址

    output wire no_dcache             // 输出：是否经过数据缓存
);

    // 分别判断指令虚拟地址和数据虚拟地址的KSEG0、KSEG1段
    wire inst_kseg0, inst_kseg1;
    wire data_kseg0, data_kseg1;

    // 判断指令虚拟地址是否属于KSEG0或KSEG1段
    assign inst_kseg0 = inst_vaddr[31:29] == 3'b100;  // KSEG0: 虚拟地址的高3位为100
    assign inst_kseg1 = inst_vaddr[31:29] == 3'b101;  // KSEG1: 虚拟地址的高3位为101

    // 判断数据虚拟地址是否属于KSEG0或KSEG1段
    assign data_kseg0 = data_vaddr[31:29] == 3'b100;  // KSEG0: 虚拟地址的高3位为100
    assign data_kseg1 = data_vaddr[31:29] == 3'b101;  // KSEG1: 虚拟地址的高3位为101

    // 根据KSEG0或KSEG1段，进行虚拟地址到物理地址的转换
    assign inst_paddr = inst_kseg0 | inst_kseg1 ? 
           {3'b0, inst_vaddr[28:0]} : inst_vaddr;  // 如果在KSEG0或KSEG1，清除虚拟地址的高3位
    assign data_paddr = data_kseg0 | data_kseg1 ? 
           {3'b0, data_vaddr[28:0]} : data_vaddr;  // 如果在KSEG0或KSEG1，清除虚拟地址的高3位
    
    // 如果数据虚拟地址位于KSEG1段，表示不需要经过数据缓存
    assign no_dcache = data_kseg1 ? 1'b1 : 1'b0;  // 如果在KSEG1段，标记不需要经过数据缓存

endmodule
