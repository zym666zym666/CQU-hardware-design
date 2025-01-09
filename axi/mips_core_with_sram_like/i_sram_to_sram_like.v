// 模块名称：i_sram_to_sram_like
// 功能：将指令SRAM接口转换为类似SRAM的接口
module i_sram_to_sram_like(
    input wire clk, rst,  // 时钟和复位信号
    // SRAM接口
    input wire inst_sram_en,  // 指令SRAM使能信号
    input wire [31:0] inst_sram_addr,  // 指令SRAM地址
    output wire [31:0] inst_sram_rdata,  // 指令SRAM读数据
    output wire i_stall,  // 指令SRAM接口的阻塞信号

    // 类似SRAM的接口
    output wire inst_req,  // 指令请求信号
    output wire inst_wr,  // 指令写信号（始终为0，表示只读）
    output wire [1:0] inst_size,  // 指令数据大小（固定为2'b10，表示32位）
    output wire [31:0] inst_addr,  // 指令地址
    output wire [31:0] inst_wdata,  // 指令写数据（始终为0，表示只读）
    input wire inst_addr_ok,  // 地址握手成功信号
    input wire inst_data_ok,  // 数据握手成功信号
    input wire [31:0] inst_rdata,  // 指令读数据

    input wire longest_stall  // 最长阻塞信号
);

    // 地址握手成功标志
    reg addr_rcv;
    // 读事务结束标志
    reg do_finish;

    // 地址握手成功标志的控制逻辑
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :  // 复位时清零
                      inst_req & inst_addr_ok & ~inst_data_ok ? 1'b1 :  // 当请求有效且地址握手成功且数据未握手时，置为1
                      inst_data_ok ? 1'b0 : addr_rcv;  // 当数据握手成功时，清零
    end

    // 读事务结束标志的控制逻辑
    always @(posedge clk) begin
        do_finish <= rst ? 1'b0 :  // 复位时清零
                        inst_data_ok ? 1'b1 :  // 当数据握手成功时，置为1
                        ~longest_stall ? 1'b0 : do_finish;  // 当不是最长阻塞时，清零
    end

    // 保存读数据的寄存器
    reg [31:0] inst_rdata_save;
    // 读数据保存逻辑
    always @(posedge clk) begin
        inst_rdata_save <= rst ? 32'b0 :  // 复位时清零
                            inst_data_ok ? inst_rdata : inst_rdata_save;  // 当数据握手成功时，保存读数据
    end

    // 类似SRAM接口的信号赋值
    assign inst_req = inst_sram_en & ~addr_rcv & ~do_finish;  // 当指令SRAM使能且地址未握手且事务未结束时，请求数据
    assign inst_wr = 1'b0;  // 指令接口为只读，写信号始终为0
    assign inst_size = 2'b10;  // 指令数据大小固定为32位
    assign inst_addr = inst_sram_addr;  // 地址直接传递
    assign inst_wdata = 32'b0;  // 写数据始终为0，表示只读

    // SRAM接口的信号赋值
    assign inst_sram_rdata = inst_rdata_save;  // 读数据从保存的寄存器中获取
    assign i_stall = inst_sram_en & ~do_finish;  // 当指令SRAM使能且事务未结束时，阻塞
endmodule