`timescale 1ns / 1ps
`include "../defines2.vh"

// eqcmp模块 - 比较两个32位输入（a 和 b），根据操作码（opD）生成一个输出信号（y）
// 主要用于判断各种条件语句，例如跳转指令的条件是否成立（如BEQ, BNE, BGTZ等）

module eqcmp(
    input wire [31:0] a,        // 第一个操作数
    input wire [31:0] b,        // 第二个操作数
    input wire [5:0] opD,       // 操作码，用于确定比较类型（BEQ, BNE, 等）
    input wire [4:0] rtD,       // rt寄存器值，供REGIMM_INST指令使用（如BGEZ, BLTZ等）
    output reg y                // 比较结果，条件成立则y为1，否则为0
);

    // 根据操作码 opD 的不同，选择不同的比较条件
    always @(*) begin
        case(opD)
            `BEQ: y = (a == b);                      // BEQ: 等于比较
            `BNE: y = (a != b);                     // BNE: 不等于比较
            `BGTZ: y = ((a[31] == 1'b0) && (a != `ZeroWord));  // BGTZ: 大于零
            `BLEZ: y = ((a[31] == 1'b1) || (a == `ZeroWord));  // BLEZ: 小于等于零
            `REGIMM_INST: begin
                case(rtD) 
                    `BGEZ, `BGEZAL: y = (a[31] == 1'b0); // BGEZ, BGEZAL: a >= 0
                    `BLTZ, `BLTZAL: y = (a[31] == 1'b1); // BLTZ, BLTZAL: a < 0
                    default: y = 1'b0;                  // 默认无条件满足
                endcase
            end
            default: y = 1'b0;                        // 默认无条件满足
        endcase
    end
endmodule

