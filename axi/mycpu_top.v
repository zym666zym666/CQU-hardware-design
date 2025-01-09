// 模块名称：mycpu_top
// 功能：顶层模块，封装了一个简单的CPU及其与外部AXI总线的接口
// bridge_1x2：桥接模块，将CPU的数据请求分为两路，一路发送到RAM，另一路发送到配置寄存器.
// cache：缓存模块，用于存储指令和数据，提高访问速度，减少对主存储器的访问次数.
// bridge_2x1：桥接模块，将来自缓存和配置寄存器的数据请求合并，发送到AXI接口.
// cpu_axi_interface：接口模块，将CPU的请求转换为AXI总线信号，实现与外部AXI总线的通信.

// 指令相关信号主要涉及AXI的读取部分（arid, araddr, arlen, arsize, arvalid等）和数据响应部分（rdata, rvalid, rready等）。
// 数据相关信号主要涉及AXI的写入部分（awid, awaddr, awdata, wvalid等）和写响应部分（bresp, bvalid, bready等）。
// 指令的访问通常只涉及 只读存储，而数据的访问涉及更复杂的读写交互、外设通信等。因此，数据访问的路径通常需要桥接模块来进行适当的转发和调度。

// 绕过缓存时，CPU 请求会直接访问 配置空间（数据来源也是通过axi访问ram）
// 启用缓存时，CPU 请求会首先访问 缓存，如果缓存未命中，则访问 RAM。
module mycpu_top(
    input [5:0] ext_int,  // 外部中断信号，6位宽，用于接收外部中断请求

    input wire aclk,     // AXI总线时钟信号
    input wire aresetn,  // AXI总线复位信号，低电平有效

    // AXI读地址通道信号
    output wire[3:0] arid,     // 读地址通道的ID
    output wire[31:0] araddr,  // 读地址
    output wire[7:0] arlen,    // 读长度，表示一次读操作的数据项数
    output wire[2:0] arsize,   // 读数据大小，表示每次传输的数据宽度
    output wire[1:0] arburst,  // 读突发类型，如固定、递增等
    output wire[1:0] arlock,   // 读锁定类型
    output wire[3:0] arcache,  // 读缓存属性
    output wire[2:0] arprot,   // 读保护属性
    output wire arvalid,       // 读地址有效信号
    input wire arready,        // 读地址就绪信号

    // AXI读数据通道信号
    input wire[3:0] rid,       // 读数据通道的ID
    input wire[31:0] rdata,    // 读数据
    input wire[1:0] rresp,     // 读响应信号
    input wire rlast,          // 读数据最后一项信号
    input wire rvalid,         // 读数据有效信号
    output wire rready,        // 读数据就绪信号

    // AXI写地址通道信号
    output wire[3:0] awid,     // 写地址通道的ID
    output wire[31:0] awaddr,  // 写地址
    output wire[7:0] awlen,    // 写长度
    output wire[2:0] awsize,   // 写数据大小
    output wire[1:0] awburst,  // 写突发类型
    output wire[1:0] awlock,   // 写锁定类型
    output wire[3:0] awcache,  // 写缓存属性
    output wire[2:0] awprot,   // 写保护属性
    output wire awvalid,       // 写地址有效信号
    input wire awready,        // 写地址就绪信号

    // AXI写数据通道信号
    output wire[3:0] wid,      // 写数据通道的ID
    output wire[31:0] wdata,   // 写数据
    output wire[3:0] wstrb,    // 写选通信号，表示哪些字节有效
    output wire wlast,         // 写数据最后一项信号
    output wire wvalid,        // 写数据有效信号
    input wire wready,         // 写数据就绪信号

    // AXI写响应通道信号
    input wire[3:0] bid,       // 写响应通道的ID
    input wire[1:0] bresp,     // 写响应信号
    input bvalid,              // 写响应有效信号
    output bready,             // 写响应就绪信号

    // 调试接口信号
    output wire[31:0] debug_wb_pc,        // 写回阶段的程序计数器值
    output wire[3:0] debug_wb_rf_wen,     // 写回阶段寄存器文件写使能
    output wire[4:0] debug_wb_rf_wnum,    // 写回阶段寄存器文件写编号
    output wire[31:0] debug_wb_rf_wdata   // 写回阶段寄存器文件写数据
);
wire clk, rst;
assign clk = aclk;
assign rst = ~aresetn;

wire        cpu_inst_req  ;
wire [31:0] cpu_inst_addr ;
wire        cpu_inst_wr   ;
wire [1:0]  cpu_inst_size ;
wire [31:0] cpu_inst_wdata;
wire [31:0] cpu_inst_rdata;
wire        cpu_inst_addr_ok;
wire        cpu_inst_data_ok;

wire        cpu_data_req  ;
wire [31:0] cpu_data_addr ;
wire        cpu_data_wr   ;
wire [1:0]  cpu_data_size ;
wire [31:0] cpu_data_wdata;
wire [31:0] cpu_data_rdata;
wire        cpu_data_addr_ok;
wire        cpu_data_data_ok;

wire        cache_inst_req  ;
wire [31:0] cache_inst_addr ;
wire        cache_inst_wr   ;
wire [1:0]  cache_inst_size ;
wire [31:0] cache_inst_wdata;
wire [31:0] cache_inst_rdata;
wire        cache_inst_addr_ok;
wire        cache_inst_data_ok;

wire        cache_data_req  ;
wire [31:0] cache_data_addr ;
wire        cache_data_wr   ;
wire [1:0]  cache_data_size ;
wire [31:0] cache_data_wdata;
wire [31:0] cache_data_rdata;
wire        cache_data_addr_ok;
wire        cache_data_data_ok;

wire        ram_data_req  ;
wire [31:0] ram_data_addr ;
wire        ram_data_wr   ;
wire [1:0]  ram_data_size ;
wire [31:0] ram_data_wdata;
wire [31:0] ram_data_rdata;
wire        ram_data_addr_ok;
wire        ram_data_data_ok;

wire        conf_data_req  ;
wire [31:0] conf_data_addr ;
wire        conf_data_wr   ;
wire [1:0]  conf_data_size ;
wire [31:0] conf_data_wdata;
wire [31:0] conf_data_rdata;
wire        conf_data_addr_ok;
wire        conf_data_data_ok;

wire        wrap_data_req  ;
wire [31:0] wrap_data_addr ;
wire        wrap_data_wr   ;
wire [1:0]  wrap_data_size ;
wire [31:0] wrap_data_wdata;
wire [31:0] wrap_data_rdata;
wire        wrap_data_addr_ok;
wire        wrap_data_data_ok;

mips_with_sram_like mips_with_sram_like(
    .clk(clk), .rst(rst),
    .ext_int(ext_int),

    .inst_req     (cpu_inst_req  ),
    .inst_wr      (cpu_inst_wr   ),
    .inst_addr    (cpu_inst_addr ),
    .inst_size    (cpu_inst_size ),
    .inst_wdata   (cpu_inst_wdata),
    .inst_rdata   (cpu_inst_rdata),
    .inst_addr_ok (cpu_inst_addr_ok),
    .inst_data_ok (cpu_inst_data_ok),

    .data_req     (cpu_data_req  ),
    .data_wr      (cpu_data_wr   ),
    .data_addr    (cpu_data_addr ),
    .data_wdata   (cpu_data_wdata),
    .data_size    (cpu_data_size ),
    .data_rdata   (cpu_data_rdata),
    .data_addr_ok (cpu_data_addr_ok),
    .data_data_ok (cpu_data_data_ok),

    .debug_wb_pc       (debug_wb_pc       ),
    .debug_wb_rf_wen   (debug_wb_rf_wen   ),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
    .debug_wb_rf_wdata (debug_wb_rf_wdata )
);

wire [31:0] cpu_inst_paddr;
wire [31:0] cpu_data_paddr;
wire no_dcache;

mmu mmu(
    .inst_vaddr(cpu_inst_addr ),
    .inst_paddr(cpu_inst_paddr),
    .data_vaddr(cpu_data_addr ),
    .data_paddr(cpu_data_paddr),
    .no_dcache (no_dcache    )
);

bridge_1x2 bridge_1x2(
    .no_dcache        (no_dcache    ),

    .cpu_data_req     (cpu_data_req  ),
    .cpu_data_wr      (cpu_data_wr   ),
    .cpu_data_addr    (cpu_data_paddr ),
    .cpu_data_wdata   (cpu_data_wdata),
    .cpu_data_size    (cpu_data_size ),
    .cpu_data_rdata   (cpu_data_rdata),
    .cpu_data_addr_ok (cpu_data_addr_ok),
    .cpu_data_data_ok (cpu_data_data_ok),

    .ram_data_req     (ram_data_req  ),
    .ram_data_wr      (ram_data_wr   ),
    .ram_data_addr    (ram_data_addr ),
    .ram_data_wdata   (ram_data_wdata),
    .ram_data_size    (ram_data_size ),
    .ram_data_rdata   (ram_data_rdata),
    .ram_data_addr_ok (ram_data_addr_ok),
    .ram_data_data_ok (ram_data_data_ok),

    .conf_data_req     (conf_data_req  ),
    .conf_data_wr      (conf_data_wr   ),
    .conf_data_addr    (conf_data_addr ),
    .conf_data_wdata   (conf_data_wdata),
    .conf_data_size    (conf_data_size ),
    .conf_data_rdata   (conf_data_rdata),
    .conf_data_addr_ok (conf_data_addr_ok),
    .conf_data_data_ok (conf_data_data_ok)
);

cache cache(
    .clk(clk), .rst(rst),
    .cpu_inst_req     (cpu_inst_req  ),
    .cpu_inst_wr      (cpu_inst_wr   ),
    .cpu_inst_addr    (cpu_inst_paddr ),
    .cpu_inst_size    (cpu_inst_size ),
    .cpu_inst_wdata   (cpu_inst_wdata),
    .cpu_inst_rdata   (cpu_inst_rdata),
    .cpu_inst_addr_ok (cpu_inst_addr_ok),
    .cpu_inst_data_ok (cpu_inst_data_ok),

    .cpu_data_req     (ram_data_req  ),
    .cpu_data_wr      (ram_data_wr   ),
    .cpu_data_addr    (ram_data_addr ),
    .cpu_data_wdata   (ram_data_wdata),
    .cpu_data_size    (ram_data_size ),
    .cpu_data_rdata   (ram_data_rdata),//输出ram_data_rdata：在dcache里面命中时返回缓存数据，否则返回AXI数据cache_data_rdata，即对应bridge_2x1的ram_data_rdata,也就是从axi外部访问。
    .cpu_data_addr_ok (ram_data_addr_ok),
    .cpu_data_data_ok (ram_data_data_ok),

    .cache_inst_req     (cache_inst_req  ),
    .cache_inst_wr      (cache_inst_wr   ),
    .cache_inst_addr    (cache_inst_addr ),
    .cache_inst_size    (cache_inst_size ),
    .cache_inst_wdata   (cache_inst_wdata),
    .cache_inst_rdata   (cache_inst_rdata),
    .cache_inst_addr_ok (cache_inst_addr_ok),
    .cache_inst_data_ok (cache_inst_data_ok),

    .cache_data_req     (cache_data_req  ),
    .cache_data_wr      (cache_data_wr   ),
    .cache_data_addr    (cache_data_addr ),
    .cache_data_wdata   (cache_data_wdata),
    .cache_data_size    (cache_data_size ),
    .cache_data_rdata   (cache_data_rdata),
    .cache_data_addr_ok (cache_data_addr_ok),
    .cache_data_data_ok (cache_data_data_ok)
);

bridge_2x1 bridge_2x1(
    .no_dcache        (no_dcache    ),

    .ram_data_req     (cache_data_req  ),
    .ram_data_wr      (cache_data_wr   ),
    .ram_data_addr    (cache_data_addr ),
    .ram_data_wdata   (cache_data_wdata),
    .ram_data_size    (cache_data_size ),
    .ram_data_rdata   (cache_data_rdata),//输出axi外部访问到的数据
    .ram_data_addr_ok (cache_data_addr_ok),
    .ram_data_data_ok (cache_data_data_ok),

    .conf_data_req     (conf_data_req  ),
    .conf_data_wr      (conf_data_wr   ),
    .conf_data_addr    (conf_data_addr ),
    .conf_data_wdata   (conf_data_wdata),
    .conf_data_size    (conf_data_size ),
    .conf_data_rdata   (conf_data_rdata),
    .conf_data_addr_ok (conf_data_addr_ok),
    .conf_data_data_ok (conf_data_data_ok),

    .wrap_data_req     (wrap_data_req  ),
    .wrap_data_wr      (wrap_data_wr   ),
    .wrap_data_addr    (wrap_data_addr ),
    .wrap_data_wdata   (wrap_data_wdata),
    .wrap_data_size    (wrap_data_size ),
    .wrap_data_rdata   (wrap_data_rdata),
    .wrap_data_addr_ok (wrap_data_addr_ok),
    .wrap_data_data_ok (wrap_data_data_ok)
);

cpu_axi_interface cpu_axi_interface(
    .clk(clk),
    .resetn(~rst),

    .inst_req       (cache_inst_req  ),
    .inst_wr        (cache_inst_wr   ),
    .inst_size      (cache_inst_size ),
    .inst_addr      (cache_inst_addr ),
    .inst_wdata     (cache_inst_wdata),
    .inst_rdata     (cache_inst_rdata),
    .inst_addr_ok   (cache_inst_addr_ok),
    .inst_data_ok   (cache_inst_data_ok),

    .data_req       (wrap_data_req  ),
    .data_wr        (wrap_data_wr   ),
    .data_size      (wrap_data_size ),
    .data_addr      (wrap_data_addr ),
    .data_wdata     (wrap_data_wdata ),
    .data_rdata     (wrap_data_rdata),
    .data_addr_ok   (wrap_data_addr_ok),
    .data_data_ok   (wrap_data_data_ok),

    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),

    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),

    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),

    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),

    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready)
);

endmodule