transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vmap -link {C:/Users/Lenovo/Desktop/colab/CO-lab-material-CQU/vivado/perf_test_v0.01/soc_axi_perf_demo/run_vivado/mycpu_prj1/mycpu.cache/compile_simlib/activehdl}
vlib activehdl/xpm
vlib activehdl/axi_infrastructure_v1_1_0
vlib activehdl/fifo_generator_v13_2_8
vlib activehdl/axi_clock_converter_v2_1_27
vlib activehdl/xil_defaultlib

vlog -work xpm  -sv2k12 "+incdir+../../../ipstatic/hdl" -l xpm -l axi_infrastructure_v1_1_0 -l fifo_generator_v13_2_8 -l axi_clock_converter_v2_1_27 -l xil_defaultlib \
"G:/vivado/Vivado/2023.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"G:/vivado/Vivado/2023.1/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  \
"G:/vivado/Vivado/2023.1/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work axi_infrastructure_v1_1_0  -v2k5 "+incdir+../../../ipstatic/hdl" -l xpm -l axi_infrastructure_v1_1_0 -l fifo_generator_v13_2_8 -l axi_clock_converter_v2_1_27 -l xil_defaultlib \
"../../../ipstatic/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work fifo_generator_v13_2_8  -v2k5 "+incdir+../../../ipstatic/hdl" -l xpm -l axi_infrastructure_v1_1_0 -l fifo_generator_v13_2_8 -l axi_clock_converter_v2_1_27 -l xil_defaultlib \
"../../../ipstatic/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_8 -93  \
"../../../ipstatic/hdl/fifo_generator_v13_2_rfs.vhd" \

vlog -work fifo_generator_v13_2_8  -v2k5 "+incdir+../../../ipstatic/hdl" -l xpm -l axi_infrastructure_v1_1_0 -l fifo_generator_v13_2_8 -l axi_clock_converter_v2_1_27 -l xil_defaultlib \
"../../../ipstatic/hdl/fifo_generator_v13_2_rfs.v" \

vlog -work axi_clock_converter_v2_1_27  -v2k5 "+incdir+../../../ipstatic/hdl" -l xpm -l axi_infrastructure_v1_1_0 -l fifo_generator_v13_2_8 -l axi_clock_converter_v2_1_27 -l xil_defaultlib \
"../../../ipstatic/hdl/axi_clock_converter_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../ipstatic/hdl" -l xpm -l axi_infrastructure_v1_1_0 -l fifo_generator_v13_2_8 -l axi_clock_converter_v2_1_27 -l xil_defaultlib \
"../../../../../../rtl/xilinx_ip/axi_clock_converter/sim/axi_clock_converter.v" \

vlog -work xil_defaultlib \
"glbl.v"

