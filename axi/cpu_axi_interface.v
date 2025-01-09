// 模块名称：cpu_axi_interface
// 功能：实现 CPU 与 AXI 总线之间的接口转换

// 当 inst_req 为 1，指令请求生效，inst_rdata 会从 rdata 获取指令数据。
// 当 data_req 为 1，数据请求生效，data_rdata 会从 rdata 获取数据。
// 指令和数据的访问通常共享一个存储体
module cpu_axi_interface(
    input         clk,          // 时钟信号
    input         resetn,       // 复位信号，低电平有效

    // 指令 SRAM-like 接口
    input         inst_req,     // 指令请求信号
    input         inst_wr,      // 指令写信号
    input  [1 :0] inst_size,    // 指令数据大小
    input  [31:0] inst_addr,    // 指令地址
    input  [31:0] inst_wdata,   // 指令写数据
    output [31:0] inst_rdata,   // 指令读数据
    output        inst_addr_ok, // 指令地址握手信号
    output        inst_data_ok, // 指令数据握手信号

    // 数据 SRAM-like 接口
    input         data_req,     // 数据请求信号
    input         data_wr,      // 数据写信号
    input  [1 :0] data_size,    // 数据大小
    input  [31:0] data_addr,    // 数据地址
    input  [31:0] data_wdata,   // 数据写数据
    output [31:0] data_rdata,   // 数据读数据
    output        data_addr_ok, // 数据地址握手信号
    output        data_data_ok, // 数据数据握手信号

    // AXI 总线接口
    // 读地址通道
    output [3 :0] arid,         // 读地址 ID
    output [31:0] araddr,       // 读地址
    output [7 :0] arlen,        // 读长度
    output [2 :0] arsize,       // 读数据大小
    output [1 :0] arburst,      // 读突发类型
    output [1 :0] arlock,       // 读锁定类型
    output [3 :0] arcache,      // 读缓存属性
    output [2 :0] arprot,       // 读保护属性
    output        arvalid,      // 读地址有效信号
    input         arready,      // 读地址就绪信号

    // 读数据通道
    input  [3 :0] rid,          // 读数据 ID
    input  [31:0] rdata,        // 读数据
    input  [1 :0] rresp,        // 读响应信号
    input         rlast,        // 读数据最后一项信号
    input         rvalid,       // 读数据有效信号
    output        rready,       // 读数据就绪信号

    // 写地址通道
    output [3 :0] awid,         // 写地址 ID
    output [31:0] awaddr,       // 写地址
    output [7 :0] awlen,        // 写长度
    output [2 :0] awsize,       // 写数据大小
    output [1 :0] awburst,      // 写突发类型
    output [1 :0] awlock,       // 写锁定类型
    output [3 :0] awcache,      // 写缓存属性
    output [2 :0] awprot,       // 写保护属性
    output        awvalid,      // 写地址有效信号
    input         awready,      // 写地址就绪信号

    // 写数据通道
    output [3 :0] wid,          // 写数据 ID
    output [31:0] wdata,        // 写数据
    output [3 :0] wstrb,        // 写选通信号
    output        wlast,        // 写数据最后一项信号
    output        wvalid,       // 写数据有效信号
    input         wready,       // 写数据就绪信号

    // 写响应通道
    input  [3 :0] bid,          // 写响应 ID
    input  [1 :0] bresp,        // 写响应信号
    input         bvalid,       // 写响应有效信号
    output        bready        // 写响应就绪信号
);

    // 地址请求标志
    reg do_req;
    // 请求类型标志，1表示数据请求，0表示指令请求
    reg do_req_or;
    // 写请求标志
    reg do_wr_r;
    // 数据大小寄存器
    reg [1 :0] do_size_r;
    // 地址寄存器
    reg [31:0] do_addr_r;
    // 写数据寄存器
    reg [31:0] do_wdata_r;
    // 数据返回标志
    wire data_back;

    // 指令地址握手信号逻辑
    assign inst_addr_ok = !do_req && !data_req;  // 当没有正在进行的请求且没有新的数据请求时，指令地址握手成功
    // 数据地址握手信号逻辑
    assign data_addr_ok = !do_req;  // 当没有正在进行的请求时，数据地址握手成功

    // 地址请求和数据返回的控制逻辑
    always @(posedge clk) begin
        do_req     <= !resetn                       ? 1'b0 : 
                      (inst_req || data_req) && !do_req ? 1'b1 :  // 当有新的请求且没有正在进行的请求时，启动新的请求
                      data_back                     ? 1'b0 : do_req;  // 当数据返回时，结束当前请求
        do_req_or  <= !resetn ? 1'b0 : 
                      !do_req ? data_req : do_req_or;  // 如果没有正在进行的请求且当前有数据请求，则设置为数据请求

        do_wr_r    <= data_req && data_addr_ok ? data_wr :  // 当数据请求且地址握手成功时，更新写请求标志
                      inst_req && inst_addr_ok ? inst_wr : do_wr_r;  // 当指令请求且地址握手成功时，更新写请求标志
        do_size_r  <= data_req && data_addr_ok ? data_size :  // 当数据请求且地址握手成功时，更新数据大小
                      inst_req && inst_addr_ok ? inst_size : do_size_r;  // 当指令请求且地址握手成功时，更新数据大小
        do_addr_r  <= data_req && data_addr_ok ? data_addr :  // 当数据请求且地址握手成功时，更新地址
                      inst_req && inst_addr_ok ? inst_addr : do_addr_r;  // 当指令请求且地址握手成功时，更新地址
        do_wdata_r <= data_req && data_addr_ok ? data_wdata :  // 当数据请求且地址握手成功时，更新写数据
                      inst_req && inst_addr_ok ? inst_wdata : do_wdata_r;  // 当指令请求且地址握手成功时，更新写数据
    end

    // 指令和数据的握手信号逻辑
    assign inst_data_ok = do_req && !do_req_or && data_back;  // 当有正在进行的请求且为指令请求且数据返回时，指令数据握手成功
    assign data_data_ok = do_req && do_req_or && data_back;  // 当有正在进行的请求且为数据请求且数据返回时，数据数据握手成功
    // 指令和数据的读数据赋值
    assign inst_rdata   = rdata;  // 指令读数据直接从 AXI 读数据通道获取
    assign data_rdata   = rdata;  // 数据读数据直接从 AXI 读数据通道获取

    // 地址接收和写数据接收的标志
    reg addr_rcv;
    reg wdata_rcv;

    // 数据返回条件
    assign data_back = addr_rcv && (rvalid && rready || bvalid && bready);  // 当地址接收成功且读数据或写响应有效时，数据返回

    // 地址接收和写数据接收的控制逻辑
    always @(posedge clk) begin
        addr_rcv  <= !resetn          ? 1'b0 :
                     arvalid && arready ? 1'b1 :  // 当读地址有效且就绪时，地址接收成功
                     awvalid && awready ? 1'b1 :  // 当写地址有效且就绪时，地址接收成功
                     data_back        ? 1'b0 : addr_rcv;  // 当数据返回时，地址接收标志清零
        wdata_rcv <= !resetn        ? 1'b0 :
                     wvalid && wready ? 1'b1 :  // 当写数据有效且就绪时，写数据接收成功
                     data_back      ?1'b0 : wdata_rcv;  // 当数据返回时，写数据接收标志清零
    end

    // 读地址通道信号赋值
    assign arid    = 4'd0;         // 读地址 ID，固定为 0
    assign araddr  = do_addr_r;    // 读地址来自当前请求的地址寄存器
    assign arlen   = 8'd0;         // 读长度固定为 0，表示单次读操作
    assign arsize  = do_size_r;    // 读数据大小根据当前请求的数据大小
    assign arburst = 2'd0;         // 读突发类型为固定
    assign arlock  = 2'd0;         // 读锁定类型为正常
    assign arcache = 4'd0;         // 读缓存属性为正常
    assign arprot  = 3'd0;         // 读保护属性为正常
    assign arvalid = do_req && !do_wr_r && !addr_rcv;  // 当有请求且为读操作且地址未接收时，读地址有效

    // 读数据通道信号赋值
    assign rready  = 1'b1;  // 总是准备好接收读数据

    // 写地址通道信号赋值
    assign awid    = 4'd0;         // 写地址 ID，固定为 0
    assign awaddr  = do_addr_r;    // 写地址来自当前请求的地址寄存器
    assign awlen   = 8'd0;         // 写长度固定为 0，表示单次写操作
    assign awsize  = do_size_r;    // 写数据大小根据当前请求的数据大小
    assign awburst = 2'd0;         // 写突发类型为固定
    assign awlock  = 2'd0;         // 写锁定类型为正常
    assign awcache = 4'd0;         // 写缓存属性为正常
    assign awprot  = 3'd0;         // 写保护属性为正常
    assign awvalid = do_req && do_wr_r && !addr_rcv;  // 当有请求且为写操作且地址未接收时，写地址有效

    // 写数据通道信号赋值
    assign wid    = 4'd0;          // 写数据 ID，固定为 0
    assign wdata  = do_wdata_r;    // 写数据来自当前请求的写数据寄存器
    assign wstrb  = do_size_r == 2'd0 ? 4'b0001 << do_addr_r[1:0] :  // 单字节写
                    do_size_r == 2'd1 ? 4'b0011 << do_addr_r[1:0] :  // 双字节写
                    4'b1111;  // 四字节写
    assign wlast  = 1'b1;         // 每次写操作都是最后一项
    assign wvalid = do_req && do_wr_r && !wdata_rcv;  // 当有请求且为写操作且写数据未接收时，写数据有效

    // 写响应通道信号赋值
    assign bready = 1'b1;  // 总是准备好接收写响应

endmodule