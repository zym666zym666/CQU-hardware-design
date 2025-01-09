// 模块名称：bridge_1x2
// 功能：桥接模块，将 CPU 的数据请求路由到 RAM 或配置空间（Conf）

// conf_data_rdata，ram_data_rdata都是通过axi与外界交互。
module bridge_1x2 (
    input no_dcache,  // 是否绕过数据缓存的信号

    // CPU 数据接口
    input         cpu_data_req,     // CPU 数据请求信号
    input         cpu_data_wr,      // CPU 数据写信号
    input  [1 :0] cpu_data_size,    // CPU 数据大小
    input  [31:0] cpu_data_addr,    // CPU 数据地址
    input  [31:0] cpu_data_wdata,   // CPU 数据写数据
    output [31:0] cpu_data_rdata,   // CPU 数据读数据
    output        cpu_data_addr_ok, // CPU 地址握手信号
    output        cpu_data_data_ok, // CPU 数据握手信号

    // RAM 数据接口
    output         ram_data_req,     // RAM 数据请求信号
    output         ram_data_wr,      // RAM 数据写信号
    output  [1 :0] ram_data_size,    // RAM 数据大小
    output  [31:0] ram_data_addr,    // RAM 数据地址
    output  [31:0] ram_data_wdata,   // RAM 数据写数据
    input   [31:0] ram_data_rdata,   // RAM 数据读数据
    input          ram_data_addr_ok, // RAM 地址握手信号
    input          ram_data_data_ok, // RAM 数据握手信号

    // 配置空间数据接口
    output         conf_data_req,    // 配置空间数据请求信号
    output         conf_data_wr,     // 配置空间数据写信号
    output  [1 :0] conf_data_size,   // 配置空间数据大小
    output  [31:0] conf_data_addr,   // 配置空间数据地址
    output  [31:0] conf_data_wdata,  // 配置空间数据写数据
    input   [31:0] conf_data_rdata,  // 配置空间数据读数据
    input          conf_data_addr_ok,// 配置空间地址握手信号
    input          conf_data_data_ok // 配置空间数据握手信号
);

    // 根据 no_dcache 信号选择数据源
    assign cpu_data_rdata   = no_dcache ? conf_data_rdata   : ram_data_rdata;  // 如果绕过缓存，从配置空间获取数据，否则从 RAM 获取
    assign cpu_data_addr_ok = no_dcache ? conf_data_addr_ok : ram_data_addr_ok; // 如果绕过缓存，使用配置空间的地址握手信号，否则使用 RAM 的
    assign cpu_data_data_ok = no_dcache ? conf_data_data_ok : ram_data_data_ok; // 如果绕过缓存，使用配置空间的数据握手信号，否则使用 RAM 的

    // 根据 no_dcache 信号选择目标接口
    assign ram_data_req   = no_dcache ? 0 : cpu_data_req;  // 如果不绕过缓存，将请求发送到 RAM
    assign ram_data_wr    = no_dcache ? 0 : cpu_data_wr;   // 如果不绕过缓存，将写信号发送到 RAM
    assign ram_data_size  = no_dcache ? 0 : cpu_data_size; // 如果不绕过缓存，将数据大小发送到 RAM
    assign ram_data_addr  = no_dcache ? 0 : cpu_data_addr; // 如果不绕过缓存，将地址发送到 RAM
    assign ram_data_wdata = no_dcache ? 0 : cpu_data_wdata; // 如果不绕过缓存，将写数据发送到 RAM

    // 如果绕过缓存，将请求发送到配置空间
    assign conf_data_req   = no_dcache ? cpu_data_req   : 0;
    assign conf_data_wr    = no_dcache ? cpu_data_wr    : 0;
    assign conf_data_size  = no_dcache ? cpu_data_size  : 0;
    assign conf_data_addr  = no_dcache ? cpu_data_addr  : 0;
    assign conf_data_wdata = no_dcache ? cpu_data_wdata : 0;

endmodule