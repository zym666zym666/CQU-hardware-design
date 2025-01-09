`timescale 1ns / 1ps
`include "../defines2.vh"

module cp0_reg(
    input wire clk,               // 时钟信号
    input wire rst,               // 复位信号
    input wire we_i,              // 写使能信号
    input[4:0] waddr_i,           // 写地址
    input[4:0] raddr_i,           // 读地址
    input[`RegBus] data_i,        // 写入数据
    input wire[5:0] int_i,        // 中断信号
    input wire[`RegBus] excepttype_i, // 异常类型
    input wire[`RegBus] current_inst_addr_i, // 当前指令地址
    input wire is_in_delayslot_i,  // 是否在延迟槽中
    input wire[`RegBus] bad_addr_i, // 错误地址

    output reg[`RegBus] data_o,   // 读出数据
    output reg[`RegBus] count_o,  // 计数器寄存器
    output reg[`RegBus] compare_o, // 比较寄存器
    output reg[`RegBus] status_o,  // 状态寄存器
    output reg[`RegBus] cause_o,   // 原因寄存器
    output reg[`RegBus] epc_o,     // 异常程序计数器
    output reg[`RegBus] config_o,  // 配置寄存器
    output reg[`RegBus] prid_o,    // 产品ID寄存器
    output reg[`RegBus] badvaddr,  // 错误地址寄存器
    output reg timer_int_o         // 定时器中断信号
    );

    // 在时钟上升沿触发的always块
    always @(posedge clk) begin
        // 如果复位信号有效
        if(rst == `RstEnable) begin
            // 初始化寄存器的值
            count_o <= `ZeroWord;
            compare_o <= `ZeroWord;
            status_o <= 32'b00010000000000000000000000000000;
            cause_o <= `ZeroWord;
            epc_o <= `ZeroWord;
            config_o <= 32'b00000000000000001000000000000000;
            prid_o <= 32'b00000000010011000000000100000010;
            timer_int_o <= `InterruptNotAssert;
        end else begin
            // 计数器递增
            count_o <= count_o + 1;
            // 更新原因寄存器中的中断信息
            cause_o[15:10] <= int_i;
            // 如果计数器值等于比较寄存器值，则触发定时器中断
            if(compare_o != `ZeroWord && count_o == compare_o) begin
                timer_int_o <= `InterruptAssert;
            end
            // 如果写使能信号有效
            if(we_i == `WriteEnable) begin
                // 根据写地址更新相应的寄存器
                case (waddr_i)
                    `CP0_REG_COUNT:begin 
                        count_o <= data_i;
                    end
                    `CP0_REG_COMPARE:begin 
                        compare_o <= data_i;
                        timer_int_o <= `InterruptNotAssert;
                    end
                    `CP0_REG_STATUS:begin 
                        status_o <= data_i;
                    end
                    `CP0_REG_CAUSE:begin 
                        cause_o[9:8] <= data_i[9:8];
                        cause_o[23] <= data_i[23];
                        cause_o[22] <= data_i[22];
                    end
                    `CP0_REG_EPC:begin 
                        epc_o <= data_i;
                    end
                    default : /* default */;
                endcase
            end
            // 根据异常类型更新寄存器
            case (excepttype_i)
                32'h00000000:begin // 中断
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin 
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b00000;
                end
                32'h00000004:begin // 取指非对齐或Load非对齐
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin 
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b00100;
                    badvaddr <= bad_addr_i;
                end
                32'h00000005:begin // Store非对齐
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin 
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b00101;
                    badvaddr <= bad_addr_i;
                end
                32'h00000008:begin // Syscall异常
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin 
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b01000;
                end
                32'h00000009:begin // BREAK异常
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin 
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b01001;
                end
                32'h0000000a:begin // 保留指令（译码失败）
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin 
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b01010;
                end
                32'h0000000c:begin // ALU溢出异常
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin 
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b01100;
                end
                32'h0000000d:begin // 自陷指令（不在57条中）
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;
                    end else begin 
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b01101;
                end
				32'h0000000e:begin // eret异常（准确说不叫异常，但
				                    // 通过这个在跳转到epc的同时清零status的EXL）
                    status_o[1] <= 1'b0;
                end
                default : /* default */;
            endcase
        end
    end

    // 组合逻辑always块，用于读取寄存器的值
    always @(*) begin
        // 如果复位信号有效
        if(rst == `RstEnable) begin
            // 将读出数据设置为零
            data_o <= `ZeroWord;
        end else begin 
            // 根据读地址选择相应的寄存器值输出
            case (raddr_i)
                `CP0_REG_COUNT:begin 
                    data_o <= count_o;
                end
                `CP0_REG_COMPARE:begin 
                    data_o <= compare_o;
                end
                `CP0_REG_STATUS:begin 
                    data_o <= status_o;
                end
                `CP0_REG_CAUSE:begin 
                    data_o <= cause_o;
                end
                `CP0_REG_EPC:begin 
                    data_o <= epc_o;
                end
                `CP0_REG_PRID:begin 
                    data_o <= prid_o;
                end
                `CP0_REG_CONFIG:begin 
                    data_o <= config_o;
                end
                `CP0_REG_BADVADDR:begin 
                    data_o <= badvaddr;
                end
                default : begin 
                    data_o <= `ZeroWord;
                end
            endcase
        end
    end
endmodule