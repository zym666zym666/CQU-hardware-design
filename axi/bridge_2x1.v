// 模块名称：bridge_2x1
// 功能：桥接模块，将 RAM 和配置空间的数据请求合并为一个请求，发送到外部接口（wrap）
module bridge_2x1 (
    input no_dcache,  // 是否绕过数据缓存的信号

    // RAM 数据接口
    input         ram_data_req,     // RAM 数据请求信号
    input         ram_data_wr,      // RAM 数据写信号
    input  [1 :0] ram_data_size,    // RAM 数据大小
    input  [31:0] ram_data_addr,    // RAM 数据地址
    input  [31:0] ram_data_wdata,   // RAM 数据写数据
    output [31:0] ram_data_rdata,   // RAM 数据读数据
    output        ram_data_addr_ok, // RAM 地址握手信号
    output        ram_data_data_ok, // RAM 数据握手信号

    // 配置空间数据接口
    input         conf_data_req,    // 配置空间数据请求信号
    input         conf_data_wr,     // 配置空间数据写信号
    input  [1 :0] conf_data_size,   // 配置空间数据大小
    input  [31:0] conf_data_addr,   // 配置空间数据地址
    input  [31:0] conf_data_wdata,  // 配置空间数据写数据
    output [31:0] conf_data_rdata,  // 配置空间数据读数据
    output        conf_data_addr_ok,// 配置空间地址握手信号
    output        conf_data_data_ok,// 配置空间数据握手信号

    // 外部接口（wrap）数据接口
    output        wrap_data_req,    // 外部接口数据请求信号
    output        wrap_data_wr,     // 外部接口数据写信号
    output [1 :0] wrap_data_size,   // 外部接口数据大小
    output [31:0] wrap_data_addr,   // 外部接口数据地址
    output [31:0] wrap_data_wdata,  // 外部接口数据写数据
    input  [31:0] wrap_data_rdata,  // 外部接口数据读数据
    input         wrap_data_addr_ok,// 外部接口地址握手信号
    input         wrap_data_data_ok // 外部接口数据握手信号
);

    // 根据 no_dcache 信号选择数据源
    assign ram_data_rdata   = no_dcache ? 0 : wrap_data_rdata;  // 如果不绕过缓存，从外部接口获取数据，否则返回0
    assign ram_data_addr_ok = no_dcache ? 0 : wrap_data_addr_ok; // 如果不绕过缓存，使用外部接口的地址握手信号，否则返回0
    assign ram_data_data_ok = no_dcache ? 0 : wrap_data_data_ok; // 如果不绕过缓存，使用外部接口的数据握手信号，否则返回0

    assign conf_data_rdata   = no_dcache ? wrap_data_rdata   : 0; // 如果绕过缓存，从外部接口获取数据，否则返回0
    assign conf_data_addr_ok = no_dcache ? wrap_data_addr_ok : 0; // 如果绕过缓存，使用外部接口的地址握手信号，否则返回0
    assign conf_data_data_ok = no_dcache ? wrap_data_data_ok : 0; // 如果绕过缓存，使用外部接口的数据握手信号，否则返回0

    // 根据 no_dcache 信号选择目标接口
    assign wrap_data_req   = no_dcache ? conf_data_req   : ram_data_req;  // 如果绕过缓存，将请求发送到外部接口，否则从 RAM 获取
    assign wrap_data_wr    = no_dcache ? conf_data_wr    : ram_data_wr;   // 如果绕过缓存，将写信号发送到外部接口，否则从 RAM 获取
    assign wrap_data_size  = no_dcache ? conf_data_size  : ram_data_size; // 如果绕过缓存，将数据大小发送到外部接口，否则从 RAM 获取
    assign wrap_data_addr  = no_dcache ? conf_data_addr  : ram_data_addr; // 如果绕过缓存，将地址发送到外部接口，否则从 RAM 获取
    assign wrap_data_wdata = no_dcache ? conf_data_wdata : ram_data_wdata; // 如果绕过缓存，将写数据发送到外部接口，否则从 RAM 获取

endmodule