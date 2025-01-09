// 模块名称：d_sram_to_sram_like
// 功能：将双端口SRAM接口转换为类似SRAM的接口
module d_sram_to_sram_like(
    input wire clk, rst,  // 时钟和复位信号
    // SRAM接口
    input wire data_sram_en,  // SRAM使能信号
    input wire [31:0] data_sram_addr,  // SRAM地址
    output wire [31:0] data_sram_rdata,  // SRAM读数据
    input wire [3:0] data_sram_wen,  // SRAM写使能信号（4位，表示字节使能）
    input wire [31:0] data_sram_wdata,  // SRAM写数据
    output wire d_stall,  // SRAM接口的阻塞信号

    // 类似SRAM的接口
    output wire data_req,  // 数据请求信号
    output wire data_wr,  // 数据写信号
    output wire [1:0] data_size,  // 数据大小（2位，表示字节大小）
    output wire [31:0] data_addr,  // 数据地址
    output wire [31:0] data_wdata,  // 数据写数据

    input wire [31:0] data_rdata,  // 数据读数据
    input wire data_addr_ok,  // 地址握手成功信号
    input wire data_data_ok,  // 数据握手成功信号

    input wire longest_stall  // 最长阻塞信号
);

    // 地址握手成功标志
    reg addr_rcv;
    // 读写事务结束标志
    reg do_finish;

    // 地址握手成功标志的控制逻辑
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :  // 复位时清零
                      data_req & data_addr_ok & ~data_data_ok ? 1'b1 :  // 当请求有效且地址握手成功且数据未握手时，置为1
                      data_data_ok ? 1'b0 : addr_rcv;  // 当数据握手成功时，清零
    end

    // 读写事务结束标志的控制逻辑
    always @(posedge clk) begin
        do_finish <= rst ? 1'b0 :  // 复位时清零
                        data_data_ok ? 1'b1 :  // 当数据握手成功时，置为1
                        ~longest_stall ? 1'b0 : do_finish;  // 当不是最长阻塞时，清零
    end

    // 保存读数据的寄存器
    reg [31:0] data_rdata_save;
    // 读数据保存逻辑
    always @(posedge clk) begin
        data_rdata_save <= rst ? 32'b0 :  // 复位时清零
                            data_data_ok ? data_rdata : data_rdata_save;  // 当数据握手成功时，保存读数据
    end

    // 类似SRAM接口的信号赋值
    assign data_req = data_sram_en & ~addr_rcv & ~do_finish;  // 当SRAM使能且地址未握手且事务未结束时，请求数据
    assign data_wr = data_sram_en & |data_sram_wen;  // 当SRAM使能且写使能有效时，写数据
    assign data_size = (data_sram_wen == 4'b0001 || data_sram_wen == 4'b0010 || data_sram_wen == 4'b0100 || data_sram_wen == 4'b1000) ? 2'b00 :  // 单字节写
                       (data_sram_wen == 4'b0011 || data_sram_wen == 4'b1100) ? 2'b01 : 2'b10;  // 双字节写或四字节写
    assign data_addr = data_sram_addr;  // 地址直接传递
    assign data_wdata = data_sram_wdata;  // 写数据直接传递

    // SRAM接口的信号赋值
    assign data_sram_rdata = data_rdata_save;  // 读数据从保存的寄存器中获取
    assign d_stall = data_sram_en & ~do_finish;  // 当SRAM使能且事务未结束时，阻塞
endmodule