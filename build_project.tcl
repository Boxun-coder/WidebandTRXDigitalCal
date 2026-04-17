set origin_dir [file normalize [file dirname [info script]]]
set project_name ads7_ad9164_custom
set project_dir [file normalize [file join $origin_dir vivado $project_name]]
set project_part xc7vx330tffg1157-3
set bd_name ads7_ad9164_bd

proc pick_ipdef {pattern} {
  set defs [lsort [get_ipdefs -all $pattern]]
  if {[llength $defs] == 0} {
    error "Unable to locate IP that matches '$pattern'."
  }
  return [lindex $defs end]
}

proc safe_set_property {obj prop value} {
  if {[catch {set_property $prop $value $obj} msg]} {
    puts "WARNING: could not set $prop on $obj -> $msg"
  }
}

proc safe_set_dict {obj dict_values} {
  if {[catch {set_property -dict $dict_values $obj} msg]} {
    puts "WARNING: could not apply property dict to $obj -> $msg"
  }
}

proc first_or_empty {collection} {
  if {[llength $collection] == 0} {
    return ""
  }
  return [lindex $collection 0]
}

proc safe_connect_net {src dst} {
  if {$src eq "" || $dst eq ""} {
    puts "WARNING: skipped net connection because one endpoint is empty: '$src' -> '$dst'"
    return
  }
  if {[catch {connect_bd_net $src $dst} msg]} {
    puts "WARNING: could not connect $src -> $dst : $msg"
  }
}

proc safe_connect_intf {src dst} {
  if {$src eq "" || $dst eq ""} {
    puts "WARNING: skipped interface connection because one endpoint is empty: '$src' -> '$dst'"
    return
  }
  if {[catch {connect_bd_intf_net $src $dst} msg]} {
    puts "WARNING: could not connect interface $src -> $dst : $msg"
  }
}

proc safe_pin {pattern} {
  return [first_or_empty [get_bd_pins -quiet -hier -regexp $pattern]]
}

proc safe_intf {pattern} {
  return [first_or_empty [get_bd_intf_pins -quiet -hier -regexp $pattern]]
}

proc ensure_ip_repo_packaged {origin_dir} {
  set component_xml [file join $origin_dir chirp_axi_stream_ip component.xml]
  if {![file exists $component_xml]} {
    puts "Packaging chirp AXI-Stream IP because component.xml is missing."
    source [file join $origin_dir chirp_axi_stream_ip package_ip.tcl]
  }
}

file mkdir [file dirname $project_dir]
ensure_ip_repo_packaged $origin_dir

if {[file exists $project_dir]} {
  close_project -quiet
  file delete -force $project_dir
}

create_project -force $project_name $project_dir -part $project_part
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property ip_repo_paths [list [file join $origin_dir chirp_axi_stream_ip]] [current_project]
update_ip_catalog

create_bd_design $bd_name

set mb_ip [create_bd_cell -type ip -vlnv [pick_ipdef "*:microblaze:*"] microblaze_0]
apply_bd_automation -rule xilinx.com:bd_rule:microblaze [get_bd_cells microblaze_0]

set clk_port [first_or_empty [get_bd_ports -quiet -filter {TYPE == clk}]]
if {$clk_port ne ""} {
  set_property name sys_clk $clk_port
}
set rst_port [first_or_empty [get_bd_ports -quiet -filter {DIR == I && TYPE == rst}]]
if {$rst_port ne ""} {
  set_property name sys_rst_n $rst_port
  catch {set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports sys_rst_n]}
}

set uart_ip [create_bd_cell -type ip -vlnv [pick_ipdef "*:axi_uartlite:*"] axi_uartlite_0]
safe_set_dict [get_bd_cells axi_uartlite_0] [list CONFIG.C_BAUDRATE {115200} CONFIG.C_DATA_BITS {8}]

set spi_ip [create_bd_cell -type ip -vlnv [pick_ipdef "*:axi_quad_spi:*"] axi_quad_spi_0]
safe_set_dict [get_bd_cells axi_quad_spi_0] [list CONFIG.C_NUM_SS_BITS {3} CONFIG.C_USE_STARTUP {0} CONFIG.C_SCK_RATIO {16} CONFIG.C_SPI_MODE {0}]

foreach {name width} {
  axi_gpio_dac_ctrl 8
  axi_gpio_chirp_ctrl 8
  axi_gpio_chirp_nsamp 32
  axi_gpio_chirp_step_init 32
  axi_gpio_chirp_step_delta 32
  axi_gpio_chirp_step_limit 32
} {
  create_bd_cell -type ip -vlnv [pick_ipdef "*:axi_gpio:*"] $name
  safe_set_dict [get_bd_cells $name] [list CONFIG.C_GPIO_WIDTH $width CONFIG.C_ALL_OUTPUTS {1}]
}

create_bd_cell -type ip -vlnv [pick_ipdef "*:xlconstant:*"] xlconstant_spi_en
safe_set_dict [get_bd_cells xlconstant_spi_en] [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {0}]

foreach {slice_name dout_from dout_to} {
  xlslice_dac_reset 0 0
  xlslice_dac_txen0 1 1
  xlslice_hmc849    2 2
  xlslice_scope_trig 3 3
} {
  create_bd_cell -type ip -vlnv [pick_ipdef "*:xlslice:*"] $slice_name
  safe_set_dict [get_bd_cells $slice_name] [list CONFIG.DIN_WIDTH {8} CONFIG.DIN_FROM {7} CONFIG.DIN_TO {0} CONFIG.DOUT_WIDTH {1} CONFIG.DOUT_FROM $dout_from CONFIG.DOUT_TO $dout_to]
}

create_bd_cell -type ip -vlnv [pick_ipdef "*:chirp_axi_stream:*"] chirp_axi_stream_0
create_bd_cell -type ip -vlnv [pick_ipdef "*:axis_data_fifo:*"] axis_data_fifo_0
create_bd_cell -type ip -vlnv [pick_ipdef "*:axis_dwidth_converter:*"] axis_dwidth_converter_0
safe_set_dict [get_bd_cells axis_data_fifo_0] [list CONFIG.TDATA_NUM_BYTES {2}]
safe_set_dict [get_bd_cells axis_dwidth_converter_0] [list CONFIG.S_TDATA_NUM_BYTES {2} CONFIG.M_TDATA_NUM_BYTES {16}]

create_bd_cell -type ip -vlnv [pick_ipdef "*:jesd204:*"] jesd204_tx_0
safe_set_dict [get_bd_cells jesd204_tx_0] [list \
  CONFIG.C_NODE_IS_TRANSMIT {1} \
  CONFIG.C_LANES {8} \
  CONFIG.C_NUM_OF_CONVERTERS {2} \
  CONFIG.C_SAMPLES_PER_FRAME {2} \
  CONFIG.C_SAMPLE_WIDTH {16} \
  CONFIG.C_SUBCLASS {1} \
  CONFIG.C_SCRAMBLING {1}]

foreach ip_name {
  axi_uartlite_0
  axi_quad_spi_0
  axi_gpio_dac_ctrl
  axi_gpio_chirp_ctrl
  axi_gpio_chirp_nsamp
  axi_gpio_chirp_step_init
  axi_gpio_chirp_step_delta
  axi_gpio_chirp_step_limit
  jesd204_tx_0
} {
  if {[llength [get_bd_intf_pins -quiet ${ip_name}/S_AXI]]} {
    apply_bd_automation -rule xilinx.com:bd_rule:axi4 [get_bd_intf_pins ${ip_name}/S_AXI]
  }
}

set axi_clk [first_or_empty [get_bd_pins -quiet -hier -filter {TYPE == clk && DIR == O}]]
set axi_rstn [first_or_empty [get_bd_pins -quiet -hier -regexp {.*peripheral_aresetn$|.*interconnect_aresetn$}]]

foreach pin_name {
  chirp_axi_stream_0/aclk
  axis_data_fifo_0/s_axis_aclk
  axis_data_fifo_0/m_axis_aclk
  axis_dwidth_converter_0/aclk
} {
  safe_connect_net $axi_clk [get_bd_pins -quiet $pin_name]
}
foreach pin_name {
  chirp_axi_stream_0/aresetn
  axis_data_fifo_0/s_axis_aresetn
  axis_data_fifo_0/m_axis_aresetn
  axis_dwidth_converter_0/aresetn
} {
  safe_connect_net $axi_rstn [get_bd_pins -quiet $pin_name]
}

safe_connect_intf [get_bd_intf_pins chirp_axi_stream_0/m_axis] [get_bd_intf_pins axis_data_fifo_0/S_AXIS]
safe_connect_intf [get_bd_intf_pins axis_data_fifo_0/M_AXIS] [get_bd_intf_pins axis_dwidth_converter_0/S_AXIS]

foreach {port_name direction width} {
  jesd_refclk I 1
  jesd_sysref I 1
  jesd_sync I 1
  fmc_spi_miso I 1
  uart_ext_rxd I 1
  dbg_chirp_tvalid O 1
  dbg_chirp_marker O 1
  dbg_chirp_tdata O 16
} {
  if {$width == 1} {
    create_bd_port -dir $direction $port_name
  } else {
    create_bd_port -dir $direction -from [expr {$width - 1}] -to 0 $port_name
  }
}

create_bd_port -dir O -from 7 -to 0 jesd_tx_p
create_bd_port -dir O -from 7 -to 0 jesd_tx_n

foreach port_name {
  fmc_spi_sclk
  fmc_spi_mosi
  fmc_spi_csn_dac
  fmc_spi_csn_clk
  fmc_spi_csn_pll
  fmc_spi_en
  fmc_dac_reset_n
  fmc_txen0
  fmc_hmc849_vctrl
  uart_ext_txd
  scope_trig
} {
  create_bd_port -dir O $port_name
}

safe_connect_net [get_bd_ports dbg_chirp_tvalid] [get_bd_pins chirp_axi_stream_0/m_axis_tvalid]
safe_connect_net [get_bd_ports dbg_chirp_marker] [get_bd_pins chirp_axi_stream_0/marker_out]
safe_connect_net [get_bd_ports dbg_chirp_tdata] [get_bd_pins chirp_axi_stream_0/debug_tdata]

safe_connect_net [get_bd_pins chirp_axi_stream_0/control_flags] [get_bd_pins axi_gpio_chirp_ctrl/gpio_io_o]
safe_connect_net [get_bd_pins chirp_axi_stream_0/cfg_num_samples] [get_bd_pins axi_gpio_chirp_nsamp/gpio_io_o]
safe_connect_net [get_bd_pins chirp_axi_stream_0/cfg_phase_step_init] [get_bd_pins axi_gpio_chirp_step_init/gpio_io_o]
safe_connect_net [get_bd_pins chirp_axi_stream_0/cfg_phase_step_delta] [get_bd_pins axi_gpio_chirp_step_delta/gpio_io_o]
safe_connect_net [get_bd_pins chirp_axi_stream_0/cfg_phase_step_limit] [get_bd_pins axi_gpio_chirp_step_limit/gpio_io_o]

safe_connect_net [get_bd_pins axi_gpio_dac_ctrl/gpio_io_o] [get_bd_pins xlslice_dac_reset/Din]
safe_connect_net [get_bd_pins axi_gpio_dac_ctrl/gpio_io_o] [get_bd_pins xlslice_dac_txen0/Din]
safe_connect_net [get_bd_pins axi_gpio_dac_ctrl/gpio_io_o] [get_bd_pins xlslice_hmc849/Din]
safe_connect_net [get_bd_pins axi_gpio_dac_ctrl/gpio_io_o] [get_bd_pins xlslice_scope_trig/Din]

safe_connect_net [get_bd_ports fmc_dac_reset_n] [get_bd_pins xlslice_dac_reset/Dout]
safe_connect_net [get_bd_ports fmc_txen0] [get_bd_pins xlslice_dac_txen0/Dout]
safe_connect_net [get_bd_ports fmc_hmc849_vctrl] [get_bd_pins xlslice_hmc849/Dout]
safe_connect_net [get_bd_ports fmc_spi_en] [get_bd_pins xlconstant_spi_en/dout]
safe_connect_net [get_bd_ports scope_trig] [get_bd_pins xlslice_scope_trig/Dout]

set jesd_axis_tdata [first_or_empty [get_bd_pins -quiet -hier -regexp {.*jesd204_tx_0.*/(s_axis_tdata|tx_tdata)$}]]
set jesd_axis_tvalid [first_or_empty [get_bd_pins -quiet -hier -regexp {.*jesd204_tx_0.*/(s_axis_tvalid|tx_tvalid)$}]]
set jesd_axis_tready [first_or_empty [get_bd_pins -quiet -hier -regexp {.*jesd204_tx_0.*/(s_axis_tready|tx_tready)$}]]
set jesd_axis_tlast [first_or_empty [get_bd_pins -quiet -hier -regexp {.*jesd204_tx_0.*/(s_axis_tlast|tx_tlast)$}]]

safe_connect_net [get_bd_pins axis_dwidth_converter_0/M_AXIS_TDATA] $jesd_axis_tdata
safe_connect_net [get_bd_pins axis_dwidth_converter_0/M_AXIS_TVALID] $jesd_axis_tvalid
safe_connect_net $jesd_axis_tready [get_bd_pins axis_dwidth_converter_0/M_AXIS_TREADY]
safe_connect_net [get_bd_pins axis_dwidth_converter_0/M_AXIS_TLAST] $jesd_axis_tlast

safe_connect_net [get_bd_ports jesd_refclk] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*jesd204_tx_0.*/(ref_clk|gt_refclk|tx_core_clk_in)$}]]
safe_connect_net [get_bd_ports jesd_sysref] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*jesd204_tx_0.*/(sysref|tx_sysref)$}]]
safe_connect_net [get_bd_ports jesd_sync] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*jesd204_tx_0.*/(sync|tx_sync)$}]]
safe_connect_net [get_bd_ports jesd_tx_p] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*jesd204_tx_0.*/(txp|txn_p|tx_data_p)$}]]
safe_connect_net [get_bd_ports jesd_tx_n] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*jesd204_tx_0.*/(txn|txn_n|tx_data_n)$}]]

safe_connect_net [get_bd_ports uart_ext_txd] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*axi_uartlite_0.*/tx$}]]
safe_connect_net [get_bd_ports uart_ext_rxd] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*axi_uartlite_0.*/rx$}]]

safe_connect_net [get_bd_ports fmc_spi_miso] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*axi_quad_spi_0.*/io0_i$|.*axi_quad_spi_0.*/spi_miso_i$}]]
safe_connect_net [get_bd_ports fmc_spi_mosi] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*axi_quad_spi_0.*/io0_o$|.*axi_quad_spi_0.*/spi_mosi_o$}]]
safe_connect_net [get_bd_ports fmc_spi_sclk] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*axi_quad_spi_0.*/sck_o$|.*axi_quad_spi_0.*/spi_clk_o$}]]
safe_connect_net [get_bd_ports fmc_spi_csn_dac] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*axi_quad_spi_0.*/ss_o\[0\]$|.*axi_quad_spi_0.*/ss_o$}]]
safe_connect_net [get_bd_ports fmc_spi_csn_clk] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*axi_quad_spi_0.*/ss_o\[1\]$}]]
safe_connect_net [get_bd_ports fmc_spi_csn_pll] [first_or_empty [get_bd_pins -quiet -hier -regexp {.*axi_quad_spi_0.*/ss_o\[2\]$}]]

assign_bd_address
regenerate_bd_layout
save_bd_design
validate_bd_design

generate_target all [get_files [file join $project_dir $project_name.srcs sources_1 bd $bd_name $bd_name.bd]]
make_wrapper -files [get_files [file join $project_dir $project_name.srcs sources_1 bd $bd_name $bd_name.bd]] -top

add_files -norecurse [file join $origin_dir system_top.v]
add_files -fileset constrs_1 -norecurse [file join $origin_dir ads7_ad9164_custom.xdc]

set wrapper_file [file join $project_dir $project_name.gen sources_1 bd $bd_name hdl ${bd_name}_wrapper.v]
if {[file exists $wrapper_file]} {
  add_files -norecurse $wrapper_file
}
set_property top system_top [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 8
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set xsa_path [file join $origin_dir ${project_name}.xsa]
write_hw_platform -fixed -include_bit -force -file $xsa_path

puts "Hardware handoff written to $xsa_path"
