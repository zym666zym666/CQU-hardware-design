// 简单的缓存模块
module d_cache_simple (
    input wire clk, rst,  // 时钟和复位信号
    // MIPS 核心接口
    input         cpu_data_req,     // CPU 数据请求信号
    input         cpu_data_wr,      // CPU 数据写入信号
    input  [1 :0] cpu_data_size,    // CPU 数据大小（字节、半字、字）
    input  [31:0] cpu_data_addr,    // CPU 数据地址
    input  [31:0] cpu_data_wdata,   // CPU 数据写入数据
    output [31:0] cpu_data_rdata,   // CPU 数据读取数据
    output        cpu_data_addr_ok, // CPU 地址确认信号
    output        cpu_data_data_ok, // CPU 数据确认信号

    // AXI 接口
    output         cache_data_req,   // 缓存数据请求信号
    output         cache_data_wr,    // 缓存数据写入信号
    output  [1 :0] cache_data_size,  // 缓存数据大小
    output  [31:0] cache_data_addr,  // 缓存数据地址
    output  [31:0] cache_data_wdata, // 缓存数据写入数据
    input   [31:0] cache_data_rdata, // 缓存数据读取数据
    input          cache_data_addr_ok, // 缓存地址确认信号
    input          cache_data_data_ok  // 缓存数据确认信号
);

    // 缓存参数
    parameter  INDEX_WIDTH  = 10, OFFSET_WIDTH = 2;  // 索引和偏移宽度
    localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;  // 标签宽度
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;  // 缓存深度

    // 缓存存储元素
    reg                 cache_valid [CACHE_DEEPTH - 1 : 0];  // 缓存行有效位
    reg [TAG_WIDTH-1:0] cache_tag   [CACHE_DEEPTH - 1 : 0];  // 缓存行标签
    reg [31:0]          cache_block [CACHE_DEEPTH - 1 : 0];  // 缓存行数据块

    // 地址解析
    wire [INDEX_WIDTH-1:0] index;  // 缓存索引
    wire [TAG_WIDTH-1:0] tag;      // 缓存标签
    assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];  // 提取索引
    assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];  // 提取标签

    // 当前缓存行
    wire c_valid;
    wire [TAG_WIDTH-1:0] c_tag;
    wire [31:0] c_block;
    assign c_valid = cache_valid[index];  // 当前索引的有效位
    assign c_tag   = cache_tag  [index];  // 当前索引的标签
    assign c_block = cache_block[index];  // 当前索引的数据块

    // 缓存命中和未命中判断
    wire hit, miss;
    assign hit = c_valid & (c_tag == tag);  // 缓存命中条件
    assign miss = ~hit;                     // 缓存未命中条件

    // 读写信号
    wire read, write;
    assign write = cpu_data_wr;             // 写入信号
    assign read = ~write;                   // 读取信号

    // 状态机
    parameter IDLE = 2'b00, RM = 2'b01, WM = 2'b11;  // 状态定义
    reg [1:0] state;  // 状态寄存器
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;  // 复位时进入空闲状态
        end
        else begin
            case(state)
                IDLE:   state <= cpu_data_req & read & miss ? RM :  // 读请求且未命中进入读取模式
                                 cpu_data_req & read & hit  ? IDLE :  // 读请求且命中保持空闲
                                 cpu_data_req & write       ? WM : IDLE;  // 写请求进入写入模式
                RM:     state <= read & cache_data_data_ok ? IDLE : RM;  // 读取模式下数据确认则返回空闲
                WM:     state <= write & cache_data_data_ok ? IDLE : WM;  // 写入模式下数据确认则返回空闲
            endcase
        end
    end

    // 读操作控制
    wire read_req;      // 读请求信号
    reg addr_rcv;       // 地址接收确认
    wire read_finish;   // 读操作完成信号
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :  // 复位时清零
                    read & cache_data_req & cache_data_addr_ok ? 1'b1 :  // 地址确认时置1
                    read_finish ? 1'b0 : addr_rcv;  // 读操作完成时清零
    end
    assign read_req = state==RM;  // 读模式下发送读请求
    assign read_finish = read & cache_data_data_ok;  // 数据确认时读操作完成

    // 写操作控制
    wire write_req;     
    reg waddr_rcv;      
    wire write_finish;   
    always @(posedge clk) begin
        waddr_rcv <= rst ? 1'b0 :  // 复位时清零
                     write & cache_data_req & cache_data_addr_ok ? 1'b1 :  // 地址确认时置1
                     write_finish ? 1'b0 : waddr_rcv;  // 写操作完成时清零
    end
    assign write_req = state==WM;  // 写模式下发送写请求
    assign write_finish = write & cache_data_data_ok;  // 数据确认时写操作完成

    // 输出到 MIPS 核心
    assign cpu_data_rdata   = hit ? c_block : cache_data_rdata;  // 命中时返回缓存数据，否则返回AXI数据
    assign cpu_data_addr_ok = read & cpu_data_req & hit | cache_data_req & cache_data_addr_ok;  // 地址确认信号
    assign cpu_data_data_ok = read & cpu_data_req & hit | cache_data_data_ok;  // 数据确认信号

    // 输出到 AXI 接口
    assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;  // 发送请求信号
    assign cache_data_wr    = cpu_data_wr;  // 写入信号
    assign cache_data_size  = cpu_data_size;  // 数据大小
    assign cache_data_addr  = cpu_data_addr;  // 数据地址
    assign cache_data_wdata = cpu_data_wdata;  // 写入数据

    // 写入缓存
    reg [TAG_WIDTH-1:0] tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    always @(posedge clk) begin
        tag_save   <= rst ? 0 :  // 复位时清零
                      cpu_data_req ? tag : tag_save;  // 请求时保存标签
        index_save <= rst ? 0 :  // 复位时清零
                      cpu_data_req ? index : index_save;  // 请求时保存索引
    end

    wire [31:0] write_cache_data;
    wire [3:0] write_mask;

    // 根据地址和大小生成写入掩码
    assign write_mask = cpu_data_size==2'b00 ?  // 字节写入
                            (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
                                                (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
                            (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);  // 半字或字写入

    // 计算写入缓存数据
    assign write_cache_data = cache_block[index] & ~{{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}} | 
                              cpu_data_wdata & {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};

    integer t;
    always @(posedge clk) begin
        if(rst) begin
            for(t=0; t<CACHE_DEEPTH; t=t+1) begin   // 复位时初始化缓存为无效
                cache_valid[t] <= 0;
            end
            // cache_valid <= '{default: '0};  // 另一种初始化方式
        end
        else begin
            if(read_finish) begin  // 读操作完成时更新缓存
                cache_valid[index_save] <= 1'b1;  // 将缓存行标记为有效
                cache_tag[index_save] <= tag_save;  // 更新缓存行的标签
                cache_block[index_save] <= cache_data_rdata;  // 更新缓存行的数据
            end
            else if(write & cpu_data_req & hit) begin  // 写操作且命中时更新缓存
                cache_block[index] <= write_cache_data;  // 更新缓存行的数据
            end
        end
    end
endmodule