set log_file    $log_dir/create_bd.log

set bd_name     bd_action

create_bd_design $bd_name >> $log_file

# HLS Action
create_bd_cell -type ip -vlnv xilinx.com:hls:hls_action:1.0 hls_action

make_bd_pins_external  \
    [get_bd_pins hls_action/ap_clk] \
    [get_bd_pins hls_action/ap_rst_n] \
    [get_bd_pins hls_action/interrupt]

set_property name ap_clk [get_bd_ports ap_clk_0]
set_property name ap_rst_n [get_bd_ports ap_rst_n_0]
set_property name interrupt [get_bd_ports interrupt_0]

make_bd_intf_pins_external  \
    [get_bd_intf_pins hls_action/s_axi_ctrl_reg]

set_property name s_axi_ctrl_reg [get_bd_intf_ports s_axi_ctrl_reg_0]

# HLS Changecase
create_bd_cell -type ip -vlnv xilinx.com:hls:hls_changecase:1.0 hls_changecase
connect_bd_net [get_bd_ports ap_clk] [get_bd_pins hls_changecase/ap_clk]
connect_bd_net [get_bd_ports ap_rst_n] [get_bd_pins hls_changecase/ap_rst_n]

# Data Mover
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_datamover:5.1 axi_datamover
set_property -dict [list \
    CONFIG.c_include_mm2s {Omit} \
    CONFIG.c_include_mm2s_stsfifo {false} \
    CONFIG.c_include_s2mm_dre {true} \
    CONFIG.c_s2mm_burst_size {64} \
    CONFIG.c_mm2s_include_sf {false} \
    CONFIG.c_s2mm_include_sf {false} \
    CONFIG.c_enable_mm2s {0} \
    CONFIG.c_addr_width {64} \
    CONFIG.c_m_axi_s2mm_id_width {0} \
] [get_bd_cells axi_datamover]
set_property -dict [list \
    CONFIG.c_m_axi_s2mm_data_width.VALUE_SRC USER \
    CONFIG.c_s_axis_s2mm_tdata_width.VALUE_SRC USER\
] [get_bd_cells axi_datamover]
set_property -dict [list \
    CONFIG.c_m_axi_s2mm_data_width {512} \
    CONFIG.c_s_axis_s2mm_tdata_width {64} \
    CONFIG.c_s2mm_include_sf {true} \
] [get_bd_cells axi_datamover]
set_property -dict [list \
    CONFIG.c_include_mm2s {Full} \
    CONFIG.c_m_axi_mm2s_data_width {512} \
    CONFIG.c_m_axis_mm2s_tdata_width {64} \
    CONFIG.c_include_mm2s_dre {true} \
    CONFIG.c_mm2s_burst_size {64} \
    CONFIG.c_include_mm2s_stsfifo {true} \
    CONFIG.c_mm2s_include_sf {true} \
    CONFIG.c_m_axi_mm2s_id_width {0} \
    CONFIG.c_enable_mm2s {1} \
    CONFIG.c_single_interface {1} \
    CONFIG.c_mm2s_btt_used {23} \
    CONFIG.c_s2mm_btt_used {23}\
] [get_bd_cells axi_datamover]
set_property -dict [list \
    CONFIG.c_m_axis_mm2s_tdata_width {512} \
    CONFIG.c_s_axis_s2mm_tdata_width {512} \
] [get_bd_cells axi_datamover]

connect_bd_intf_net [get_bd_intf_pins axi_datamover/M_AXIS_S2MM_STS] [get_bd_intf_pins hls_action/s2mm_sts]
connect_bd_intf_net [get_bd_intf_pins axi_datamover/S_AXIS_S2MM_CMD] [get_bd_intf_pins hls_action/s2mm_cmd_V_V]
connect_bd_intf_net [get_bd_intf_pins axi_datamover/S_AXIS_MM2S_CMD] [get_bd_intf_pins hls_action/mm2s_cmd_V_V]
connect_bd_intf_net [get_bd_intf_pins axi_datamover/M_AXIS_MM2S_STS] [get_bd_intf_pins hls_action/mm2s_sts]

connect_bd_net [get_bd_ports ap_clk] [get_bd_pins axi_datamover/m_axi_s2mm_aclk]
connect_bd_net [get_bd_ports ap_rst_n] [get_bd_pins axi_datamover/m_axi_s2mm_aresetn]
connect_bd_net [get_bd_ports ap_clk] [get_bd_pins axi_datamover/m_axis_s2mm_cmdsts_awclk]
connect_bd_net [get_bd_ports ap_rst_n] [get_bd_pins axi_datamover/m_axis_s2mm_cmdsts_aresetn]
connect_bd_net [get_bd_ports ap_clk] [get_bd_pins axi_datamover/m_axi_mm2s_aclk]
connect_bd_net [get_bd_ports ap_rst_n] [get_bd_pins axi_datamover/m_axi_mm2s_aresetn]
connect_bd_net [get_bd_ports ap_clk] [get_bd_pins axi_datamover/m_axis_mm2s_cmdsts_aclk]
connect_bd_net [get_bd_ports ap_rst_n] [get_bd_pins axi_datamover/m_axis_mm2s_cmdsts_aresetn]

connect_bd_intf_net [get_bd_intf_pins hls_changecase/out_r] [get_bd_intf_pins axi_datamover/S_AXIS_S2MM]
connect_bd_intf_net [get_bd_intf_pins hls_changecase/in_r] [get_bd_intf_pins axi_datamover/M_AXIS_MM2S]


# Host Mem Crossbar
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_crossbar:2.1 axi_host_mem_crossbar

set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {1}] [get_bd_cells axi_host_mem_crossbar]
set_property -dict [list CONFIG.DATA_WIDTH.VALUE_SRC USER CONFIG.ADDR_WIDTH.VALUE_SRC USER] [get_bd_cells axi_host_mem_crossbar]
set_property -dict [list CONFIG.ADDR_WIDTH {64} CONFIG.DATA_WIDTH {512}] [get_bd_cells axi_host_mem_crossbar]
set_property -dict [list CONFIG.BUSER_WIDTH.VALUE_SRC USER CONFIG.RUSER_WIDTH.VALUE_SRC USER CONFIG.WUSER_WIDTH.VALUE_SRC USER] [get_bd_cells axi_host_mem_crossbar]
set_property -dict [list CONFIG.WUSER_WIDTH {1} CONFIG.RUSER_WIDTH {1} CONFIG.BUSER_WIDTH {1}] [get_bd_cells axi_host_mem_crossbar]
set_property -dict [list CONFIG.ARUSER_WIDTH.VALUE_SRC USER CONFIG.AWUSER_WIDTH.VALUE_SRC USER] [get_bd_cells axi_host_mem_crossbar]
set_property -dict [list CONFIG.AWUSER_WIDTH {8} CONFIG.ARUSER_WIDTH {8}] [get_bd_cells axi_host_mem_crossbar]
set_property -dict [list CONFIG.M00_A00_BASE_ADDR.VALUE_SRC USER CONFIG.M00_A00_ADDR_WIDTH.VALUE_SRC USER] [get_bd_cells axi_host_mem_crossbar]
set_property -dict [list CONFIG.M00_A00_BASE_ADDR {0x00000000000} CONFIG.M00_A00_ADDR_WIDTH {64}] [get_bd_cells axi_host_mem_crossbar]

connect_bd_intf_net [get_bd_intf_pins hls_action/m_axi_host_mem] [get_bd_intf_pins axi_host_mem_crossbar/S00_AXI]
connect_bd_net [get_bd_ports ap_clk] [get_bd_pins axi_host_mem_crossbar/aclk]
connect_bd_net [get_bd_ports ap_rst_n] [get_bd_pins axi_host_mem_crossbar/aresetn]

make_bd_intf_pins_external  [get_bd_intf_pins axi_host_mem_crossbar/M00_AXI]
set_property name m_axi_host_mem [get_bd_intf_ports M00_AXI_0]

if { ( $::env(DDRI_USED) == "TRUE" ) } {
    # AXI Crossbar

    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_crossbar:2.1 axi_crossbar
    connect_bd_intf_net [get_bd_intf_pins axi_datamover/M_AXI] [get_bd_intf_pins axi_crossbar/S00_AXI]

    # connect_bd_intf_net [get_bd_intf_pins axi_crossbar/M01_AXI] [get_bd_intf_pins axi_host_mem_crossbar/S01_AXI]

    make_bd_intf_pins_external  [get_bd_intf_pins axi_crossbar/M01_AXI]
    set_property name m_axi_card_mem0 [get_bd_intf_ports M01_AXI_0]

    set_property -dict [list CONFIG.ADDR_WIDTH {64} CONFIG.DATA_WIDTH {512}] [get_bd_intf_ports m_axi_host_mem]
    set_property -dict [list CONFIG.ADDR_WIDTH {64} CONFIG.DATA_WIDTH {512}] [get_bd_intf_ports m_axi_card_mem0]

    set_property -dict [list CONFIG.M00_A00_BASE_ADDR.VALUE_SRC USER CONFIG.M01_A00_BASE_ADDR.VALUE_SRC USER CONFIG.M00_A00_ADDR_WIDTH.VALUE_SRC USER CONFIG.M01_A00_ADDR_WIDTH.VALUE_SRC USER CONFIG.ADDR_WIDTH.VALUE_SRC USER] [get_bd_cells axi_crossbar]
    set_property -dict [list CONFIG.ADDR_WIDTH {64} CONFIG.M00_A00_BASE_ADDR {0} CONFIG.M01_A00_BASE_ADDR {1000000000000000000000000000000000000000000000000000000000000000} CONFIG.M00_A00_ADDR_WIDTH {63} CONFIG.M01_A00_ADDR_WIDTH {63}] [get_bd_cells axi_crossbar]

    connect_bd_net [get_bd_ports ap_clk] [get_bd_pins axi_crossbar/aclk]
    connect_bd_net [get_bd_ports ap_rst_n] [get_bd_pins axi_crossbar/aresetn]
} else {
    connect_bd_intf_net [get_bd_intf_pins axi_datamover/M_AXI] [get_bd_intf_pins axi_host_mem_crossbar/S01_AXI]

    assign_bd_address [get_bd_addr_segs {m_axi_host_mem/Reg }] >> $log_file
    set_property offset 0x0000000000000000 [get_bd_addr_segs {hls_action/Data_m_axi_host_mem/SEG_m_axi_host_mem_Reg}]
    set_property range 16E [get_bd_addr_segs {hls_action/Data_m_axi_host_mem/SEG_m_axi_host_mem_Reg}]
    set_property offset 0x0000000000000000 [get_bd_addr_segs {axi_datamover/Data/SEG_m_axi_host_mem_Reg}]
    set_property range 16E [get_bd_addr_segs {axi_datamover/Data/SEG_m_axi_host_mem_Reg}]
}

assign_bd_address >> $log_file

assign_bd_address [get_bd_addr_segs {hls_action/s_axi_ctrl_reg/Reg }]

save_bd_design >> $log_file

set_property synth_checkpoint_mode None [get_files  $src_dir/../bd/$bd_name/$bd_name.bd]
generate_target all                     [get_files  $src_dir/../bd/$bd_name/$bd_name.bd] >> $log_file
