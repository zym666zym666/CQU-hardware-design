// 包含定义文件
`include "defines2.vh"
`timescale 1ns / 1ps

// 数据通路模块定义
module datapath(
    // 输入输出端口列表
    input wire clk,rst, // 时钟和复位信号
	input wire [5:0] ext_int, // 硬件中断标识
	// 控制器接口
    output wire [31:0] instrD, // 指令寄存器D
    input wire[4:0] alucontrolD, // ALU控制信号D
    input wire memtoregD,memwriteD,branchD, // 内存访问控制信号D
		alusrcD,regwriteD,jumpD, // 寄存器和跳转控制信号D
		hilo_writeD,jbralD,jrD, // HILO寄存器和分支控制信号D
		cp0_writeD,is_invalidD, // CP0寄存器控制信号D
	input wire[1:0] regdstD, // 寄存器目标选择信号D

	// MIPS指令执行相关信号
	output wire[31:0] pcF, // 程序计数器F
	input wire[31:0] instrF, // 指令寄存器F
	output wire[31:0] aluoutM,mem_write_dataM, // ALU输出和内存写入数据M
	input wire[31:0] readdataM, // 读数据M
	output wire mem_enM, // 存储器使能信号M
	output wire [3:0] mem_wenM, // 内存写使能信号M
	// 调试接口
    output [31:0] debug_wb_pc, // 写回阶段程序计数器，用于调试
    output [3:0] debug_wb_rf_wen, // 写回阶段寄存器写使能，用于调试
    output [4:0] debug_wb_rf_wnum, // 写回阶段寄存器编号，用于调试
    output [31:0] debug_wb_rf_wdata // 写回阶段寄存器写入数据，用于调试
);

	// 内部信号声明
	// PC相关信号
	wire [31:0] pcplus4F, pcbranchD, pc4branchFD, pc4branchjFD, pc4branchjjrFD, pcnextFD;

	// F阶段数据通路
	wire stallF; // F阶段暂停信号
	wire is_AdEL_pcF; // F阶段地址对齐异常标志
	wire is_in_delayslotF; // F阶段是否在延迟槽

	// D阶段控制器
	wire pcsrcD; // D阶段分支源选择
	wire equalD; // D阶段比较结果

	// D阶段数据通路
	wire [31:0] pcplus4D; // D阶段PC+4
	wire forwardaD,forwardbD; // D阶段前向信号
	wire [5:0] opD,functD; // D阶段操作码和功能码
	wire [4:0] rsD,rtD,rdD,saD; // D阶段寄存器编号
	wire stallD,flushD; // D阶段暂停和刷新信号
	wire [31:0] signimmD,signimmshD; // D阶段立即数和位移立即数
	wire [31:0] srcaD,srca2D,srcbD,srcb2D; // D阶段源数据
	wire is_AdEL_pcD,is_syscallD,is_breakD,is_eretD; // D阶段异常标志
	wire is_in_delayslotD; // D阶段是否在延迟槽
	wire [31:0] pcD; // D阶段PC
	wire [4:0] cp0_waddrD,cp0_raddrD; // CP0寄存器读写地址

	// E阶段控制器
	wire regwriteE,alusrcE,memwriteE,memtoregE; // E阶段寄存器写入、ALU源选择、内存写入、内存寄存器选择
	wire [1:0] regdstE; // E阶段寄存器目标选择
	wire [4:0] alucontrolE; // E阶段ALU控制信号
	wire hilo_writeE; // E阶段HILO寄存器写信号
	wire is_invalidE; // E阶段无效指令标志
	wire jbralE,cp0_writeE; // E阶段跳转和CP0写入
	// E阶段数据通路
	wire [1:0] forwardaE,forwardbE; // E阶段前向信号
	wire [5:0] opE; // E阶段操作码
	wire [4:0] rsE,rtE,rdE,saE; // E阶段寄存器编号
	wire [4:0] writeregE; // E阶段写寄存器编号
	wire [31:0] signimmE; // E阶段立即数
	wire [31:0] srcaE,srca2E,srca3E, srcbE,srcb2E,srcb3E,srcb4E; // E阶段源数据
	wire [31:0] aluoutE; // E阶段ALU输出
	wire [63:0] read_hiloE,write_hiloE; // E阶段HILO读写数据
	wire hilo_write2E; // E阶段HILO寄存器写信号，考虑除法
	wire div_readyE; // E阶段除法完成标志
	wire div_stallE; // E阶段除法暂停控制信号
	wire stallE,flushE; // E阶段暂停和刷新信号
	wire is_AdEL_pcE,is_syscallE,is_breakE,is_eretE,is_overflowE; // E阶段异常标志
	wire is_in_delayslotE; // E阶段是否在延迟槽
	wire [31:0] pcE; // E阶段PC
	wire [4:0] cp0_waddrE; // E阶段CP0写地址
	wire [4:0] cp0_raddrE; // E阶段CP0读地址
	wire [31:0] cp0_rdataE,cp0_rdata2E; // E阶段CP0读数据

	// M阶段控制器
	wire regwriteM,memtoregM,memwriteM; // M阶段寄存器写入、内存寄存器选择、内存写入
	wire is_invalidM; // M阶段无效指令标志
	wire cp0_writeM; // M阶段CP0写入
	// M阶段数据通路
	wire [5:0] opM; // M阶段操作码
	wire [4:0] writeregM; // M阶段写寄存器编号
	wire [31:0] final_read_dataM,writedataM; // M阶段最终读数据和写数据
	wire flushM,stallM; // M阶段刷新和暂停信号
	wire is_AdEL_pcM,is_syscallM,is_breakM,is_eretM,is_AdEL_dataM,is_AdES_dataM,is_overflowM; // M阶段异常标志
	wire is_in_delayslotM; // M阶段是否在延迟槽
	wire [31:0] pcM; // M阶段PC
	wire [4:0] cp0_waddrM; // M阶段CP0写地址
	wire is_exceptM; // M阶段是否异常
	wire [31:0] except_typeM; // M阶段异常类型
	wire [31:0] except_pcM; // M阶段异常PC
	wire [31:0] cp0_countM,cp0_compareM,cp0_statusM,cp0_causeM, // M阶段CP0相关信号
				cp0_epcM,cp0_configM,cp0_pridM,cp0_badvaddrM; // M阶段CP0相关信号
	wire cp0_timer_intM; // M阶段CP0定时器中断
	wire [31:0] bad_addrM; // M阶段异常地址

	// W阶段控制器
	wire regwriteW,memtoregW; // W阶段寄存器写入、内存寄存器选择
	// W阶段数据通路
	wire [4:0] writeregW; // W阶段写寄存器编号
	wire [31:0] aluoutW,readdataW,resultW; // W阶段ALU输出、读数据、结果
	wire flushW,stallW; // W阶段刷新和暂停信号

	// 调试信号处理
    wire [31:0] pcW;
        // 指令寄存器，用于调试
    wire [31:0] instrE,instrM,instrW;
    // 寄存器，用于存储E、M、W阶段的指令
    flopr #(32) rinstrE(clk,rst,instrD,instrE);
    flopr #(32) rinstrM(clk,rst,instrE,instrM);
    flopr #(32) rinstrW(clk,rst,instrM,instrW);
    
    // 寄存器，用于存储W阶段的PC
    flopr #(32) rpcW(clk,rst,pcM,pcW);
    // 调试信号赋值
    assign debug_wb_pc          = pcW;
    assign debug_wb_rf_wen      = {4{regwriteW}};
    assign debug_wb_rf_wnum     = writeregW;
    assign debug_wb_rf_wdata    = resultW;

    // 控制器流水线
    assign pcsrcD = branchD & equalD; // 是否分支
    flopenrc #(15) regE(
        clk,
        rst,
        ~stallE,
        flushE,
        {memtoregD,memwriteD,alusrcD,regdstD,regwriteD,alucontrolD,hilo_writeD,jbralD,cp0_writeD,is_invalidD},
        {memtoregE,memwriteE,alusrcE,regdstE,regwriteE,alucontrolE,hilo_writeE,jbralE,cp0_writeE,is_invalidE}
    );
    floprc #(5) regM(
        clk,rst,flushM,
        {memtoregE,memwriteE,regwriteE,cp0_writeE,is_invalidE},
        {memtoregM,memwriteM,regwriteM,cp0_writeM,is_invalidM}
    );
    floprc #(2) regW(
        clk,rst,flushW,
        {memtoregM,regwriteM},
        {memtoregW,regwriteW}
    );

    // 数据通路逻辑
    // 冒险处理逻辑
    hazard h(
        // fetch stage
        stallF,
        // decode stage
        rsD,rtD,
        branchD,
        jrD,
        forwardaD,forwardbD,
        stallD,
        // execute stage
        rsE,rtE,
        writeregE,
        regwriteE,
        memtoregE,
        div_stallE,
        forwardaE,forwardbE,
        flushD,
        flushE,
        flushM,
        flushW,
        stallE,
        // mem stage
        writeregM,
        regwriteM,
        memtoregM,
        is_exceptM,
        //write back stage
        writeregW,
        regwriteW
    );

    // 下一个PC逻辑（在fetch和decode阶段操作）
    mux2 #(32) pcbrmux(pcplus4F,pcbranchD,pcsrcD,pc4branchFD); //选择分支地址或PC+4
    mux2 #(32) pcjumpmux(pc4branchFD,
        {pcplus4D[31:28],instrD[25:0],2'b00},
        jumpD,pc4branchjFD);//选择跳转地址或PC+4
    mux2 #(32) pc_jr_mux(pc4branchjFD,srca2D,jrD,pc4branchjjrFD);//选择跳转寄存器地址或跳转地址
    mux2 #(32) pc_except_mux(pc4branchjjrFD,except_pcM,is_exceptM,pcnextFD); // 处理异常添加

    // 寄存器文件（在decode和writeback阶段操作）
    regfile rf(clk,regwriteW,rsD,rtD,writeregW,resultW,srcaD,srcbD);

    // fetch阶段逻辑
    pc #(32) pcreg(clk,rst,~stallF,pcnextFD,pcF);
    adder pcadd1(pcF,32'b100,pcplus4F);//到此形成循环

    assign is_AdEL_pcF = ~(pcF[1:0] == 2'b00); // 检查地址是否对齐
    assign is_in_delayslotF = jumpD | branchD | jbralD | jrD; // 检查是否在延迟槽

    // decode阶段
    flopenrc #(32) r1D(clk,rst,~stallD,flushD,pcplus4F,pcplus4D);
    flopenrc #(32) r2D(clk,rst,~stallD,flushD,instrF,instrD);
    flopenrc #(1) r3D(clk,rst,~stallD,flushD,is_AdEL_pcF,is_AdEL_pcD);
    flopenrc #(1) r4D(clk,rst,~stallD,flushD,is_in_delayslotF,is_in_delayslotD);
    flopenrc #(32) r5D(clk,rst,~stallD,flushD,pcF,pcD);

    // 立即数符号扩展
    signext se(instrD[15:0],opD[3:2],signimmD);//op为11则为立即数
    // 立即数左移两位
    sl2 immsh(signimmD,signimmshD);
    // PC增加立即数
    adder pcadd2(pcplus4D,signimmshD,pcbranchD);
    // 前沿信号
    mux2 #(32) forwardamux(srcaD,aluoutM,forwardaD,srca2D);//冒险reg读写冲突，若写则读aluoutM
    mux2 #(32) forwardbmux(srcbD,aluoutM,forwardbD,srcb2D);
    // 比较指令
    eqcmp comp(srca2D,srcb2D,opD,rtD,equalD);//决定要不要跳转

    // 指令解码
    assign opD = instrD[31:26]; // 操作码
    assign functD = instrD[5:0]; // 功能码
    assign rsD = instrD[25:21]; // 源寄存器
    assign rtD = instrD[20:16]; // 目标寄存器
    assign rdD = instrD[15:11]; // 目的寄存器
    assign saD = instrD[10:6];  // 位移量

    // 异常和系统调用检测
    assign is_breakD = (opD == 6'b000000) & (functD == `BREAK);
    assign is_syscallD = (opD == 6'b000000) & (functD == `SYSCALL);
    assign is_eretD = (instrD == 32'b01000010000000000000000000011000);
    assign cp0_waddrD = rdD; // CP0写地址
    assign cp0_raddrD = rdD; // CP0读地址

    // execute阶段
    flopenrc #(32) r1E(clk,rst,~stallE,flushE,srcaD,srcaE);
    flopenrc #(32) r2E(clk,rst,~stallE,flushE,srcbD,srcbE);
    flopenrc #(32) r3E(clk,rst,~stallE,flushE,signimmD,signimmE);
    flopenrc #(5) r4E(clk,rst,~stallE,flushE,rsD,rsE);
    flopenrc #(5) r5E(clk,rst,~stallE,flushE,rtD,rtE);
    flopenrc #(5) r6E(clk,rst,~stallE,flushE,rdD,rdE);
    flopenrc #(5) r7E(clk,rst,~stallE,flushE,saD,saE);
    flopenrc #(6) r8E(clk,rst,~stallE,flushE,opD,opE);
    flopenrc #(4) r9E(clk,rst,~stallE,flushE,
        {is_AdEL_pcD,is_syscallD,is_breakD,is_eretD},
        {is_AdEL_pcE,is_syscallE,is_breakE,is_eretE});
    flopenrc #(1) r10E(clk,rst,~stallE,flushE,is_in_delayslotD,is_in_delayslotE);
    flopenrc #(32) r11E(clk,rst,~stallE,flushE,pcD,pcE);
    flopenrc #(5) r12E(clk,rst,~stallE,flushE,cp0_waddrD,cp0_waddrE);
    flopenrc #(5) r13E(clk,rst,~stallE,flushE,cp0_raddrD,cp0_raddrE);

    // 前沿信号
    mux3 #(32) forwardaemux(srcaE,resultW,aluoutM,forwardaE,srca2E);//旁路更新使用前面阶段写回的值
    mux3 #(32) forwardbemux(srcbE,resultW,aluoutM,forwardbE,srcb2E);
    mux2 #(32) srcbmux(srcb2E,signimmE,alusrcE,srcb3E);//选择立即数or寄存器b值
    // 跳转链接类指令，复用ALU,ALU源操作数选择分别为pcE and 8
    mux2 #(32) alusrcamux(srca2E,pcE,jbralE,srca3E);//有al的跳转指令一般计算pc+8
    mux2 #(32) alusrcbmux(srcb3E,32'h00000008,jbralE,srcb4E);
    // CP0写后读数据前推
    mux2 #(32) forwardcp0mux(cp0_rdataE,aluoutM,(cp0_raddrE == cp0_waddrM),cp0_rdata2E); //使输入alu前cp0读到数据最新

    alu alu(clk,rst,srca3E,srcb4E,alucontrolE,saE,read_hiloE,cp0_rdata2E,is_exceptM,
            write_hiloE,aluoutE,div_readyE,div_stallE,is_overflowE);
    assign hilo_write2E = (alucontrolE == `DIV_CONTROL | alucontrolE == `DIVU_CONTROL) ? 
                        (div_readyE & hilo_writeE) : (hilo_writeE); //HILO是否写
    hilo_reg hilo_reg(clk,rst,(hilo_write2E & ~is_exceptM),write_hiloE,read_hiloE);//HILO寄存器写入读出
    mux3 #(5) wrmux(rtE,rdE,5'd31,regdstE,writeregE);//确定写寄存器编号

    // mem stage
    floprc #(32) r1M(clk,rst,flushM,srcb2E,writedataM);
    floprc #(32) r2M(clk,rst,flushM,aluoutE,aluoutM);
    floprc #(5) r3M(clk,rst,flushM,writeregE,writeregM);
    floprc #(6) r4M(clk,rst,flushM,opE,opM);
    floprc #(5) r5M(clk,rst,flushM,
        {is_AdEL_pcE,is_syscallE,is_breakE,is_eretE,is_overflowE},
        {is_AdEL_pcM,is_syscallM,is_breakM,is_eretM,is_overflowM});
    floprc #(1) r6M(clk,rst,flushM,is_in_delayslotE,is_in_delayslotM);
    floprc #(32) r7M(clk,rst,flushM,pcE,pcM);
    floprc #(5) r8M(clk,rst,flushM,cp0_waddrE,cp0_waddrM);

    assign mem_enM = (~is_AdEL_dataM & ~is_AdES_dataM); // 存储器使能，防止异常地址写入或读出
    // mem_write_dataM由writedataM得出，即rt读出的值，与sw有关。final_read_dataM由readdataM得出，与lw有关
    mem_ctrl mem_ctrl(opM,aluoutM,readdataM,final_read_dataM,writedataM,mem_write_dataM,mem_wenM,is_AdEL_dataM,is_AdES_dataM);//相当于图中DATA_SEL，控制data_ram读写

    exceptdec exceptdec(
        // 输入信号
        .clk(clk),              // 时钟信号
        .rst(rst),              // 复位信号
        .ext_int(ext_int),      // 外部中断信号
        .cp0_status(cp0_statusM),  // CP0状态寄存器的值
        .cp0_cause(cp0_causeM),    // CP0异常原因寄存器的值
        .cp0_epc(cp0_epcM),        // CP0异常程序计数器的值
        .is_syscallM(is_syscallM),  // 是否是系统调用
        .is_breakM(is_breakM),      // 是否是断点异常
        .is_eretM(is_eretM),        // 是否是异常返回指令
        .is_AdEL_pcM(is_AdEL_pcM),  // 是否是地址错误异常（PC）
        .is_AdEL_dataM(is_AdEL_dataM), // 是否是地址错误异常（数据）
        .is_AdES_dataM(is_AdES_dataM), // 是否是对齐错误异常（数据）
        .is_overflowM(is_overflowM),  // 是否是溢出异常
        .is_invalidM(is_invalidM),    // 是否是无效指令异常
        // 输出信号
        .is_except(is_exceptM),       // 是否发生异常
        .except_type(except_typeM),   // 异常类型
        .except_pc(except_pcM)        // 异常发生时的程序计数器值
    );
    assign bad_addrM = is_AdEL_pcM ? pcM : aluoutM;//指出是哪个导致的错误地址
    cp0_reg cp0_reg(
        // 输入信号
        .clk(clk),                      // 时钟
        .rst(rst),                      // 复位
        .we_i(cp0_writeM),              // 写使能
        .waddr_i(cp0_waddrM),           // 写地址
        .raddr_i(cp0_raddrE),           // 读地址
        .data_i(aluoutM),               // 写数据
        .int_i(ext_int),                // 外部中断
        .excepttype_i(except_typeM),    // 异常类型
        .current_inst_addr_i(pcM),      // 当前指令地址
        .is_in_delayslot_i(is_in_delayslotM), // 是否在延迟槽
        .bad_addr_i(bad_addrM),          // 错误地址

        // 输出信号
        .data_o(cp0_rdataE),            // 读数据
        .count_o(cp0_countM),           // 计数器
        .compare_o(cp0_compareM),       // 比较器
        .status_o(cp0_statusM),         // 状态寄存器
        .cause_o(cp0_causeM),           // 原因寄存器
        .epc_o(cp0_epcM),               // 异常返回地址
        .config_o(cp0_configM),         // 配置寄存器
        .prid_o(cp0_pridM),             // 处理器ID
        .badvaddr(cp0_badvaddrM),       // 错误虚拟地址
        .timer_int_o(cp0_timer_intM)    // 定时器中断
    );

    //writeback stage
    floprc #(32) r1W(clk,rst,flushW,aluoutM,aluoutW);
    floprc #(32) r2W(clk,rst,flushW,final_read_dataM,readdataW);
    floprc #(5) r3W(clk,rst,flushW,writeregM,writeregW);
    mux2 #(32) resmux(aluoutW,readdataW,memtoregW,resultW);//选择写回是计算结果还是寄存器值

endmodule