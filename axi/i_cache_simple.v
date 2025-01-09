// 简单的指令缓存模块
module i_cache_simple (
    input wire clk, rst,  // 时钟和复位信号
    // MIPS 核心接口
    input         cpu_inst_req,     // CPU 指令请求信号
    input         cpu_inst_wr,      // CPU 指令写入信号
    input  [1 :0] cpu_inst_size,    // CPU 指令大小（字节、半字、字）
    input  [31:0] cpu_inst_addr,    // CPU 指令地址
    input  [31:0] cpu_inst_wdata,   // CPU 指令写入数据
    output [31:0] cpu_inst_rdata,   // CPU 指令读取数据
    output        cpu_inst_addr_ok, // CPU 地址确认信号
    output        cpu_inst_data_ok, // CPU 数据确认信号

    // AXI 接口
    output         cache_inst_req,   // 缓存指令请求信号
    output         cache_inst_wr,    // 缓存指令写入信号
    output  [1 :0] cache_inst_size,  // 缓存指令大小
    output  [31:0] cache_inst_addr,  // 缓存指令地址
    output  [31:0] cache_inst_wdata, // 缓存指令写入数据
    input   [31:0] cache_inst_rdata, // 缓存指令读取数据
    input          cache_inst_addr_ok, // 缓存地址确认信号
    input          cache_inst_data_ok  // 缓存数据确认信号
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
    wire [OFFSET_WIDTH-1:0] offset;  // 偏移量
    wire [INDEX_WIDTH-1:0] index;    // 缓存索引
    wire [TAG_WIDTH-1:0] tag;        // 缓存标签
    assign offset = cpu_inst_addr[OFFSET_WIDTH - 1 : 0];  // 提取偏移量
    assign index = cpu_inst_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];  // 提取索引
    assign tag = cpu_inst_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];  // 提取标签

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

    // 状态机
    parameter IDLE = 2'b00, RM = 2'b01;  // 指令缓存只进行读操作
    reg [1:0] state;  // 状态寄存器
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;  // 复位时进入空闲状态
        end
        else begin
            case(state)
                IDLE:   state <= cpu_inst_req & miss ? RM : IDLE;  // 读请求且未命中进入读取模式
                RM:     state <= cache_inst_data_ok ? IDLE : RM;  // 读取模式下数据确认则返回空闲
            endcase
        end
    end

    // 读操作控制
    wire read_req;      // 读请求信号
    reg addr_rcv;       // 地址接收确认
    wire read_finish;   // 读操作完成信号
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :  // 复位时清零
                    cache_inst_req & cache_inst_addr_ok ? 1'b1 :  // 地址确认时置1
                    read_finish ? 1'b0 : addr_rcv;  // 读操作完成时清零
    end
    assign read_req = state==RM;  // 读模式下发送读请求
    assign read_finish = cache_inst_data_ok;  // 数据确认时读操作完成

    // 输出到 MIPS 核心
    assign cpu_inst_rdata   = hit ? c_block : cache_inst_rdata;  // 命中时返回缓存数据，否则返回AXI数据
    assign cpu_inst_addr_ok = cpu_inst_req & hit | cache_inst_req & cache_inst_addr_ok;  // 地址确认信号
    assign cpu_inst_data_ok = cpu_inst_req & hit | cache_inst_data_ok;  // 数据确认信号

    // 输出到 AXI 接口
    assign cache_inst_req   = read_req & ~addr_rcv;  // 发送请求信号
    assign cache_inst_wr    = cpu_inst_wr;  // 写入信号
    assign cache_inst_size  = cpu_inst_size;  // 数据大小
    assign cache_inst_addr  = cpu_inst_addr;  // 数据地址
    assign cache_inst_wdata = cpu_inst_wdata;  // 写入数据

    // 写入缓存
    // 保存地址中的标签和索引
    reg [TAG_WIDTH-1:0] tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    always @(posedge clk) begin
        tag_save   <= rst ? 0 :  // 复位时清零
                      cpu_inst_req ? tag : tag_save;  // 请求时保存标签
        index_save <= rst ? 0 :  // 复位时清零
                      cpu_inst_req ? index : index_save;  // 请求时保存索引
    end

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
                cache_block[index_save] <= cache_inst_rdata;  // 更新缓存行的数据
            end
        end
    end
endmodule