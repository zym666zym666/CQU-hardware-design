`include "../defines2.vh"

// div模块 - 用于实现整数除法，支持有符号和无符号除法，并处理除零错误

module div(
    input wire clk,               // 时钟信号
    input wire rst,               // 复位信号
    input wire signed_div_i,      // 是否为有符号除法（1：有符号，0：无符号）
    input wire[31:0] opdata1_i,   // 被除数（操作数1）
    input wire[31:0] opdata2_i,   // 除数（操作数2）
    input wire start_i,           // 除法启动信号（1：启动）
    input wire annul_i,           // 是否取消除法操作（1：取消）
    
    output reg[63:0] result_o,    // 除法结果（64位）
    output reg ready_o            // 除法结果准备好信号（1：结果准备好）
);

    // 内部信号声明
    wire[32:0] div_temp;          // 临时除法运算结果，用于存储减法结果
    reg[5:0] cnt;                // 计数器，用于记录除法过程中的循环次数
    reg[64:0] dividend;          // 被除数，扩展到65位（包括符号位）
    reg[1:0] state;              // 状态寄存器，用于控制除法过程的状态
    reg[31:0] divisor;           // 除数
    reg[31:0] temp_op1, temp_op2; // 临时存储操作数1和操作数2

    // 计算临时减法结果，用于模拟除法过程
    assign div_temp = {1'b0, dividend[63:32]} - {1'b0, divisor};

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            // 复位状态：初始化所有状态
            state <= `DivFree;
            ready_o <= `DivResultNotReady;
            result_o <= {`ZeroWord, `ZeroWord};
        end else begin
            case (state)
                // 空闲状态，等待启动信号
                `DivFree: begin
                    if (start_i == `DivStart && annul_i == 1'b0) begin
                        if (opdata2_i == `ZeroWord) begin
                            // 如果除数为零，进入除零状态
                            state <= `DivByZero;
                        end else begin
                            // 启动除法操作
                            state <= `DivOn;
                            cnt <= 6'b000000;  // 初始化计数器
                            
                            // 处理被除数和除数的符号（如果是有符号除法）
                            if (signed_div_i == 1'b1 && opdata1_i[31] == 1'b1) begin
                                temp_op1 = ~opdata1_i + 1;  // 取负数
                            end else begin
                                temp_op1 = opdata1_i;
                            end
                            if (signed_div_i == 1'b1 && opdata2_i[31] == 1'b1) begin
                                temp_op2 = ~opdata2_i + 1;  // 取负数
                            end else begin
                                temp_op2 = opdata2_i;
                            end
                            
                            // 初始化被除数和除数
                            dividend <= {`ZeroWord, `ZeroWord};
                            dividend[32:1] <= temp_op1;
                            divisor <= temp_op2;
                        end
                    end else begin
                        // 取消或无效的除法操作
                        ready_o <= `DivResultNotReady;
                        result_o <= {`ZeroWord, `ZeroWord};
                    end
                end

                // 除数为零状态
                `DivByZero: begin
                    dividend <= {`ZeroWord, `ZeroWord};  // 清空被除数
                    state <= `DivEnd;  // 结束除法操作
                end

                // 除法计算中状态
                `DivOn: begin
                    if (annul_i == 1'b0) begin
                        if (cnt != 6'b100000) begin
                            // 除法计算中，持续进行直到计数器满
                            if (div_temp[32] == 1'b1) begin
                                dividend <= {dividend[63:0], 1'b0};  // 结果加0
                            end else begin
                                dividend <= {div_temp[31:0], dividend[31:0], 1'b1};  // 结果加1
                            end
                            cnt <= cnt + 1;  // 计数器加1
                        end else begin
                            // 除法结束处理
                            if (signed_div_i == 1'b1 && (opdata1_i[31] ^ opdata2_i[31]) == 1'b1) begin
                                dividend[31:0] <= (~dividend[31:0] + 1);  // 取负数
                            end
                            if (signed_div_i == 1'b1 && (opdata1_i[31] ^ dividend[64]) == 1'b1) begin
                                dividend[64:33] <= (~dividend[64:33] + 1);  // 取负数
                            end
                            state <= `DivEnd;  // 进入结束状态
                            cnt <= 6'b000000;  // 重置计数器
                        end
                    end else begin
                        // 如果取消操作，回到空闲状态
                        state <= `DivFree;
                    end
                end

                // 除法结束状态，输出结果
                `DivEnd: begin
                    result_o <= {dividend[64:33], dividend[31:0]};  // 结果为被除数的高32位和低32位
                    ready_o <= `DivResultReady;  // 标记结果已准备好
                    
                    if (start_i == `DivStop) begin
                        // 如果停止信号被触发，回到空闲状态
                        state <= `DivFree;
                        ready_o <= `DivResultNotReady;  // 标记结果未准备好
                        result_o <= {`ZeroWord, `ZeroWord};  // 清空结果
                    end
                end
            endcase
        end
    end

endmodule
