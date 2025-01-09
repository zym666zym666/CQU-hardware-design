`include "defines2.vh"
`timescale 1ns / 1ps

module datapath(
    input wire clk,rst,
    input wire [5:0] ext_int,	// 硬件中断标识
    // controller
    output wire [31:0] instrD,	// 解码阶段指令
    input wire[4:0] alucontrolD,	// ALU控制信号
    input wire memtoregD,		// 决定写回数据来源
    input wire memwriteD,		// 写存储器使能
    input wire branchD,			// 分支使能
    input wire alusrcD,			// ALU源操作数选择
    input wire regwriteD,		// 写寄存器使能
    input wire jumpD,			// 跳转使能
    input wire hilo_writeD,		// HILO寄存器写使能
    input wire jbralD,			// 跳转到ALU结果
    input wire jrD,				// 跳转到寄存器
    input wire cp0_writeD,		// CP0寄存器写使能
    input wire is_invalidD,		// 无效指令
    input wire[1:0] regdstD,	// 写寄存器选择
    input wire hilotoregD,		// HILO寄存器到写回数据
    input wire cp0toregD,		// CP0寄存器到写回数据
    input wire memreadD,		// 读存储器使能
    input wire [1:0] mfhi_loD,	// 选择HI或LO寄存器

    // mips
    input wire instrStall,		// 指令暂停信号
    input wire dataStall,		// 数据暂停信号
    output wire[31:0] pcF,		// 取指阶段PC
    input wire[31:0] instrF,	// 取指阶段指令
    output wire instr_enF,		// 指令使能
    output wire[31:0] aluoutM,	// 执行阶段ALU输出
    output wire[31:0] mem_write_dataM,	// 写存储器数据
    input wire[31:0] readdataM,	// 读存储器数据
    output wire mem_enM,		// 存储器使能
    output wire [3:0] mem_wenM,	// 存储器写使能

    output wire longest_stall,	// 最长暂停信号
    // for debug
    output [31:0] debug_wb_pc,	// 写回阶段PC
    output [3:0] debug_wb_rf_wen,	// 写回阶段寄存器写使能
    output [4:0] debug_wb_rf_wnum,	// 写回阶段寄存器号
    output [31:0] debug_wb_rf_wdata	// 写回阶段寄存器写数据
);
    //----------------------------------------------internal signal----------------------------------------------------	
    // PC
    wire [31:0] pcplus4F,		// PC+4
                pcbranchD,		// 分支目标PC
                pc4branchFD,	// 分支PC到取指阶段
                pc4branchjFD,	// 跳转PC到取指阶段
                pc4branchjjrFD,	// 跳转到寄存器PC到取指阶段
                pcnextFD;		// 下一个PC到取指阶段

    // F datapath
    wire stallF,flushF;		// 取指阶段暂停和刷新信号
    wire is_AdEL_pcF;		// 取指阶段PC对齐异常
    wire is_in_delayslotF;	// 当前指令是否在延迟槽

    // D controler
    wire pcsrcD;			// 计算是否要分支
    wire equalD;			// 比较结果

    // D datapath
    wire [31:0] pcplus4D;		// 解码阶段PC+4
    wire forwardaD,forwardbD;	// 数据前推信号
    wire [5:0] opD,functD;	// 操作码和功能码
    wire [4:0] rsD,rtD,rdD,saD;	// 寄存器地址和移位量
    wire stallD,flushD;		// 解码阶段暂停和刷新信号
    wire [31:0] signimmD,signimmshD;	// 立即数符号扩展和左移
    wire [31:0] srcaD,srca2D,srcbD,srcb2D;	// 源操作数
    wire is_AdEL_pcD,is_syscallD,is_breakD,is_eretD; // 异常标记
    wire is_in_delayslotD; 
    wire [31:0] pcD;		// 解码阶段PC
    wire [4:0] cp0_waddrD;	// CP0写地址，指令MTC0
    wire [4:0] cp0_raddrD;	// CP0读地址，指令MFC0
	

	    // E controler
    wire regwriteE,alusrcE,memwriteE,memtoregE,memreadE;	// 执行阶段控制信号
    wire [1:0] regdstE;		// 写寄存器选择
    wire [4:0] alucontrolE;	// ALU控制信号
    wire hilo_writeE;		// HILO寄存器写使能
    wire is_invalidE;		// 无效指令
    wire jbralE,cp0_writeE;	// 跳转到ALU结果和CP0寄存器写使能
    wire [1:0] mfhi_loE;		// 选择HI或LO寄存器

    // E datapath
    wire [1:0] forwardaE,forwardbE;	// 数据前推信号
    wire hilotoregE,cp0toregE;	// HILO和CP0寄存器到写回数据
    wire [5:0] opE;		// 操作码
    wire [4:0] rsE,rtE,rdE,saE;	// 寄存器地址和移位量
    wire [4:0] writeregE;	// 写寄存器号
    wire [31:0] signimmE;	// 立即数
    wire [31:0] srcaE,srca2E,srca3E,  srcbE,srcb2E,srcb3E,srcb4E;	// 源操作数
    wire [31:0] aluoutE;	// ALU输出
    wire [63:0] read_hiloM,All_aluoutE;	// HILO读写数据

    wire div_stallE;		// 除法导致的流水线暂停控制
    wire mul_stallE;		// 乘法流水线暂停
    wire stallE,flushE;		// 执行阶段暂停、刷新控制信号
    wire is_AdEL_pcE,is_syscallE,is_breakE,is_eretE,is_overflowE; // 异常标记
    wire is_in_delayslotE;	// 是否在延迟槽
    wire [31:0] pcE;		// 执行阶段PC
    wire [4:0] cp0_waddrE;	// CP0写地址
    wire [4:0] cp0_raddrE;	// CP0读地址
    wire [31:0] cp0_rdataE,cp0_rdata2E; // CP0寄存器数据
    wire [31:0] cp0_rdataM;	// CP0寄存器数据

    // M controller
    wire regwriteM,memtoregM,memwriteM,memreadM;	// 存储阶段控制信号
    wire hilotoregM;		// HILO寄存器到写回数据
    wire cp0toregM;		// CP0寄存器到写回数据
    wire is_invalidM;		// 无效指令
    wire cp0_writeM;		// CP0寄存器写使能
    wire hilo_writeM;		// HILO寄存器写使能
    wire [1:0] mfhi_loM;	// 选择HI或LO寄存器

    // M datapath
    wire [5:0] opM;		// 操作码
    wire [4:0] writeregM;	// 写寄存器号
    wire [31:0] final_read_dataM,writedataM;	// 存储器读写数据
    wire flushM,stallM;		// 存储阶段刷新和暂停信号
    wire is_AdEL_pcM,is_syscallM,is_breakM,is_eretM,is_AdEL_dataM,is_AdES_dataM,is_overflowM; // 异常标记
    wire is_in_delayslotM;	// 是否在延迟槽
    wire [31:0] pcM;		// 存储阶段PC
    wire [4:0] cp0_waddrM;	// CP0写地址
    wire is_exceptM;		// 是否发生异常
    wire [31:0] except_typeM;	// 异常类型
    wire [31:0] except_pcM;	// 异常PC
    wire [31:0] cp0_countM,cp0_compareM,cp0_statusM,cp0_causeM,
                cp0_epcM,cp0_configM,cp0_pridM,cp0_badvaddrM;	// CP0寄存器数据
    wire cp0_timer_intM;		// CP0定时器中断
    wire [31:0] bad_addrM;	// 异常地址
    wire [31:0] resultM;		// 写回数据
    wire [63:0] aluoutHiloM;	// HILO寄存器输出

    // W controller
    wire regwriteW,memtoregW;	// 写回阶段控制信号
    // W datapath
    wire [4:0] writeregW;		// 写回寄存器号
    wire [31:0] aluoutW,readdataW,resultW;	// 写回数据
    wire flushW,stallW;		// 写回阶段刷新和暂停信号
	
	
    //----------------------------------------------for debug begin----------------------------------------------------	
    wire [31:0] pcW;		// 写回阶段PC
    wire [31:0] instrE,instrM;	// 执行和存储阶段指令
    flopenrc #(32) rinstrE(clk,rst,~stallE,flushE,instrD,instrE);	// 执行阶段指令寄存器
    flopenrc #(32) rinstrM(clk,rst,~stallM,flushM,instrE,instrM);	// 存储阶段指令寄存器

    flopenrc #(32) rpcW(clk,rst,~stallW,flushW,pcM,pcW);	// 写回阶段PC寄存器
    assign debug_wb_pc          = pcW;		// 调试用写回阶段PC
    assign debug_wb_rf_wen      = {4{regwriteW & ~stallW}};	// 调试用寄存器写使能
    assign debug_wb_rf_wnum     = writeregW;	// 调试用寄存器号
    assign debug_wb_rf_wdata    = resultW;	// 调试用寄存器写数据
    //----------------------------------------------for debug end----------------------------------------------------

    //----------------------------------------controler pipeline------------------------------------------
    // 分支控制信号计算
    assign pcsrcD = branchD & equalD;
    // 执行阶段控制信号寄存器
    flopenrc #(20) regE(
        clk,
        rst,
        ~stallE,
        flushE,
        {memtoregD,memwriteD,alusrcD,regdstD,regwriteD,alucontrolD,hilo_writeD,jbralD,cp0_writeD,is_invalidD,hilotoregD,cp0toregD,memreadD,mfhi_loD},
        {memtoregE,memwriteE,alusrcE,regdstE,regwriteE,alucontrolE,hilo_writeE,jbralE,cp0_writeE,is_invalidE,hilotoregE,cp0toregE,memreadE,mfhi_loE}
    );
    // 存储阶段控制信号寄存器
    flopenrc #(12) regM(
        clk,
        rst,
        ~stallM,
        flushM,
        {memtoregE,memwriteE,regwriteE,cp0_writeE,is_invalidE,memreadE,cp0toregE,hilo_writeE,mfhi_loE,hilotoregE},
        {memtoregM,memwriteM,regwriteM,cp0_writeM,is_invalidM,memreadM,cp0toregM,hilo_writeM,mfhi_loM,hilotoregM}
    );
    // 写回阶段控制信号寄存器
    flopenrc #(2) regW(
        clk,
        rst,
        ~stallW,
        flushW,
        {memtoregM,regwriteM},
        {memtoregW,regwriteW}
    );
    //----------------------------------------controler pipeline end------------------------------------------

    //----------------------------------------datapath logic------------------------------------------
    // 危险检测和处理模块
    hazard h(
        // 取指阶段
        stallF,
        flushF,	// 几乎没用
        instrStall,
        // 解码阶段
        rsD,rtD,
        branchD,
        jrD,
        forwardaD,forwardbD,
        stallD,
        flushD,
        // 执行阶段
        rsE,rtE,rdE,
        writeregE,
        regwriteE,
        memtoregE,
        div_stallE,
        mul_stallE,

        hilotoregE,
        cp0toregE,

        forwardaE,forwardbE,
        stallE,
        flushE,
        // 存储阶段
        dataStall,//数据依赖暂停
        writeregM,
        regwriteM,
        memtoregM,
        is_exceptM,
        stallM,
        flushM,
        // 写回阶段
        writeregW,
        regwriteW,
        stallW,
        flushW,
        longest_stall//插入足够bubble等待必要的数据
    );

    // 下一个PC逻辑（在取指和解码阶段操作）
    mux2 #(32) pcbrmux(pcplus4F,pcbranchD,pcsrcD,pc4branchFD);	// 分支PC选择
    mux2 #(32) pcjumpmux(pc4branchFD,
        {pcplus4D[31:28],instrD[25:0],2'b00},
        jumpD,pc4branchjFD);	// 跳转PC选择
    mux2 #(32) pc_jr_mux(pc4branchjFD,srca2D,jrD,pc4branchjjrFD);	// 跳转到寄存器PC选择
    mux2 #(32) pc_except_mux(pc4branchjjrFD,except_pcM,is_exceptM,pcnextFD); // 异常PC选择

    // 寄存器文件（在解码和写回阶段操作）
    regfile rf(clk,regwriteW,rsD,rtD,writeregW,resultW,srcaD,srcbD);

    // 取指阶段逻辑
    pc #(32) pcreg(clk,rst,~stallF,pcnextFD,pcF);	// PC寄存器
    adder pcadd1(pcF,32'b100,pcplus4F);	// PC+4

    // 指令使能和异常检测
    assign instr_enF =  ~is_exceptM & ~is_AdEL_pcF;
    assign is_AdEL_pcF = ~(pcF[1:0] == 2'b00);	// PC对齐异常
    assign is_in_delayslotF = jumpD | branchD | jbralD | jrD;	// 是否在延迟槽，在M阶段影响CP0的Cause寄存器的BD位和EPC寄存器存储的返回地址。如为真则返回pc-4

    // 解码阶段
    flopenrc #(32) r1D(clk,rst,~stallD,flushD,pcplus4F,pcplus4D);	// PC+4寄存器
    flopenrc #(32) r2D(clk,rst,~stallD,flushD,instrF,instrD);	// 指令寄存器
    flopenrc #(1) r3D(clk,rst,~stallD,flushD,is_AdEL_pcF,is_AdEL_pcD);	// PC对齐异常寄存器
    flopenrc #(1) r4D(clk,rst,~stallD,flushD,is_in_delayslotF,is_in_delayslotD);	// 延迟槽寄存器
    flopenrc #(32) r5D(clk,rst,~stallD,flushD,pcF,pcD);	// PC寄存器

    signext se(instrD[15:0],opD[3:2],signimmD);	// 立即数符号扩展
    sl2 immsh(signimmD,signimmshD);		// 立即数左移两位
    adder pcadd2(pcplus4D,signimmshD,pcbranchD);	// 分支目标PC计算

    wire [31:0] toForwardM;
    assign toForwardM = resultM;	// 存储阶段结果用于前推

    mux2 #(32) forwardamux(srcaD,toForwardM,forwardaD,srca2D);	// 源操作数A前推
    mux2 #(32) forwardbmux(srcbD,toForwardM,forwardbD,srcb2D);	// 源操作数B前推
    eqcmp comp(srca2D,srcb2D,opD,rtD,equalD);	// 比较操作

    assign opD = instrD[31:26];	// 提取操作码
    assign functD = instrD[5:0];	// 提取功能码
    assign rsD = instrD[25:21];	// 提取源寄存器地址
    assign rtD = instrD[20:16];	// 提取目标寄存器地址
    assign rdD = instrD[15:11];	// 提取目的寄存器地址
    assign saD = instrD[10:6];	// 提取移位量

    assign is_breakD = (opD == 6'b000000) & (functD == `BREAK);	// 是否为BREAK指令
    assign is_syscallD = (opD == 6'b000000) & (functD == `SYSCALL);	// 是否为SYSCALL指令
    assign is_eretD = (instrD == 32'b01000010000000000000000000011000);	// 是否为ERET指令
    assign cp0_waddrD = rdD;	// CP0写地址
    assign cp0_raddrD = rdD;	// CP0读地址

    // 执行阶段
    flopenrc #(32) r1E(clk,rst,~stallE,flushE,srcaD,srcaE);	// 源操作数A寄存器
    flopenrc #(32) r2E(clk,rst,~stallE,flushE,srcbD,srcbE);	// 源操作数B寄存器
    flopenrc #(32) r3E(clk,rst,~stallE,flushE,signimmD,signimmE);	// 立即数寄存器
    flopenrc #(5) r4E(clk,rst,~stallE,flushE,rsD,rsE);	// 源寄存器地址寄存器
    flopenrc #(5) r5E(clk,rst,~stallE,flushE,rtD,rtE);	// 目标寄存器地址寄存器
    flopenrc #(5) r6E(clk,rst,~stallE,flushE,rdD,rdE);	// 目的寄存器地址寄存器
    flopenrc #(5) r7E(clk,rst,~stallE,flushE,saD,saE);	// 移位量寄存器
    flopenrc #(6) r8E(clk,rst,~stallE,flushE,opD,opE);	// 操作码寄存器
    flopenrc #(4) r9E(clk,rst,~stallE,flushE,
        {is_AdEL_pcD,is_syscallD,is_breakD,is_eretD},
        {is_AdEL_pcE,is_syscallE,is_breakE,is_eretE});
    flopenrc #(1) r10E(clk,rst,~stallE,flushE,is_in_delayslotD,is_in_delayslotE);
    flopenrc #(32) r11E(clk,rst,~stallE,flushE,pcD,pcE);
    flopenrc #(5) r12E(clk,rst,~stallE,flushE,cp0_waddrD,cp0_waddrE);
    flopenrc #(5) r13E(clk,rst,~stallE,flushE,cp0_raddrD,cp0_raddrE);

    // 数据前推和ALU操作数选择
    mux3 #(32) forwardaemux(srcaE,resultW,toForwardM,forwardaE,srca2E);
    mux3 #(32) forwardbemux(srcbE,resultW,toForwardM,forwardbE,srcb2E);
    mux2 #(32) srcbmux(srcb2E,signimmE,alusrcE,srcb3E);
    // 跳转链接类指令，复用ALU，ALU源操作数选择分别为pcE和8
    mux2 #(32) alusrcamux(srca2E,pcE,jbralE,srca3E);	// 当jbralE为真时，选择pcE作为ALU的A操作数
    mux2 #(32) alusrcbmux(srcb3E,32'h00000008,jbralE,srcb4E);	// 当jbralE为真时，选择8作为ALU的B操作数

    // CP0写后读数据前推
    mux2 #(32) forwardcp0mux(cp0_rdataE,aluoutM,(cp0_raddrE == cp0_waddrM),cp0_rdata2E);	// 如果CP0寄存器地址相同，则前推ALU输出到CP0读数据

    // ALU模块
    alu alu(clk,rst,srca3E,srcb4E,alucontrolE,saE,read_hiloM,cp0_rdata2E,is_exceptM,
            All_aluoutE,mul_stallE,div_stallE,is_overflowE);	// ALU计算，包括乘法、除法和溢出检测
    assign aluoutE = All_aluoutE[31:0];	// ALU输出
    mux3 #(5) wrmux(rtE,rdE,5'd31,regdstE,writeregE);	// 写寄存器选择，根据regdstE选择rtE或rdE

    // 存储阶段
    flopenrc #(32) r1M(clk,rst,~stallM,flushM,srcb2E,writedataM);	// 存储阶段写数据寄存器
    flopenrc #(32) r2M(clk,rst,~stallM,flushM,aluoutE,aluoutM);	// 存储阶段ALU输出寄存器
    flopenrc #(5) r3M(clk,rst,~stallM,flushM,writeregE,writeregM);	// 存储阶段写寄存器号寄存器
    flopenrc #(6) r4M(clk,rst,~stallM,flushM,opE,opM);	// 存储阶段操作码寄存器
    flopenrc #(5) r5M(clk,rst,~stallM,flushM,
        {is_AdEL_pcE,is_syscallE,is_breakE,is_eretE,is_overflowE},
        {is_AdEL_pcM,is_syscallM,is_breakM,is_eretM,is_overflowM});	// 存储阶段异常标记寄存器
    flopenrc #(1) r6M(clk,rst,~stallM,flushM,is_in_delayslotE,is_in_delayslotM);	// 存储阶段延迟槽标记寄存器
    flopenrc #(32) r7M(clk,rst,~stallM,flushM,pcE,pcM);	// 存储阶段PC寄存器
    flopenrc #(5) r8M(clk,rst,~stallM,flushM,cp0_waddrE,cp0_waddrM);	// 存储阶段CP0写地址寄存器
    flopenrc #(64) r9M(clk,rst,~stallM,flushM,All_aluoutE,aluoutHiloM);	// 存储阶段HILO寄存器输出

    // HILO寄存器模块
    hilo_reg hilo_reg(
        .clk(clk),
        .rst(rst),
        .we(hilo_writeM),		// HILO寄存器写使能
        .hilo_in(aluoutHiloM),	// HILO寄存器输入
        .hilo_out(read_hiloM)	// HILO寄存器输出
    );
    wire [31:0] hiloresultM;
    mux2 #(32) hilomux(read_hiloM[63:32],read_hiloM[31:0],mfhi_loM[0],hiloresultM);	// 选择HI或LO寄存器结果

    // 存储器使能和存储器控制模块
    assign mem_enM = (memreadM | memwriteM) & ~is_exceptM; // 存储器使能，防止异常地址写入或读出
    mem_ctrl mem_ctrl(opM,aluoutM,readdataM,final_read_dataM,writedataM,mem_write_dataM,mem_wenM,is_AdEL_dataM,is_AdES_dataM);//存储器读写控制

    // 异常检测模块
    exceptdec exceptdec(
        // input
        .clk(clk),              
        .rst(rst),              
        .ext_int(ext_int),   
        .cp0_status(cp0_statusM),  
        .cp0_cause(cp0_causeM),  
        .cp0_epc(cp0_epcM),    
        .is_syscallM(is_syscallM),      
        .is_breakM(is_breakM),        
        .is_eretM(is_eretM),         
        .is_AdEL_pcM(is_AdEL_pcM),      
        .is_AdEL_dataM(is_AdEL_dataM),    
        .is_AdES_dataM(is_AdES_dataM),         
        .is_overflowM(is_overflowM),     
        .is_invalidM(is_invalidM),   
        // output   
        .is_except(is_exceptM),       
        .except_type(except_typeM),
        .except_pc(except_pcM)   
    );
    assign bad_addrM = is_AdEL_pcM ? pcM : aluoutM;	// 异常地址选择
    wire [31:0] current_inst_addr;
    flopr #(32) except_inst_addr(clk,rst,pcE,current_inst_addr); // 写入cp0_epc, 由 pcE 传递来，无flush

    // CP0寄存器模块
    cp0_reg cp0_reg(
        // input
        .clk(clk),                          
        .rst(rst),
        .we_i(cp0_writeM & ~stallM),    
        .waddr_i(instrM[15:11]),
        .raddr_i(instrM[15:11]),
        .data_i(writedataM),  // 写入数据
        .int_i(ext_int),
        .excepttype_i(except_typeM),
        .current_inst_addr_i(current_inst_addr),  // 当前指令地址
        .is_in_delayslot_i(is_in_delayslotM),     // 是否在延迟槽
        .bad_addr_i(bad_addrM),                  // 异常地址
        // output
        .data_o(cp0_rdataM),                     // CP0寄存器读出数据
        .count_o(cp0_countM),                    // CP0计数器
        .compare_o(cp0_compareM),                // CP0比较器
        .status_o(cp0_statusM),                  // CP0状态寄存器
        .cause_o(cp0_causeM),                    // CP0原因寄存器
        .epc_o(cp0_epcM),                        // CP0异常程序计数器，即处理后返回地址
        .config_o(cp0_configM),                  // CP0配置寄存器
        .prid_o(cp0_pridM),                      // CP0处理器ID寄存器
        .badvaddr(cp0_badvaddrM),                // CP0无效地址寄存器
        .timer_int_o(cp0_timer_intM)             // CP0定时器中断
    );

    // 存储阶段结果选择
    wire [31:0] resultaM,resultbM;
    mux2 #(32) res1mux(aluoutM,final_read_dataM,memtoregM,resultaM); // 选择ALU输出或存储器读出数据
    mux2 #(32) res2mux(resultaM,cp0_rdataM,cp0toregM,resultbM);      // 选择CP0寄存器数据或前一结果
    mux2 #(32) res3mux(resultbM,hiloresultM,hilotoregM,resultM);     // 选择HILO寄存器数据或前一结果

    // 写回阶段
    flopenrc #(32) r1W(clk,rst,~stallW,flushW,aluoutM,aluoutW);	// 写回阶段ALU输出寄存器
    flopenrc #(32) r2W(clk,rst,~stallW,flushW,final_read_dataM,readdataW);	// 写回阶段存储器读出数据寄存器
    flopenrc #(5) r3W(clk,rst,~stallW,flushW,writeregM,writeregW    );	// 写回阶段写寄存器号寄存器
    flopenrc #(32) r4W(clk,rst,~stallW,flushW,resultM,resultW);	// 写回阶段结果寄存器

    //----------------------------------------datapath 模块end------------------------------------------
endmodule