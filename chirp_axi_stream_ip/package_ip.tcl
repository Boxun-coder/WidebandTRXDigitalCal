set script_dir [file normalize [file dirname [info script]]]
set package_proj_dir [file join $script_dir .pack]
set package_part xc7vx330tffg1157-3

file mkdir $package_proj_dir
create_project -force chirp_axi_stream_pkg $package_proj_dir -part $package_part
add_files [glob -nocomplain [file join $script_dir hdl *.v]]
set_property top chirp_axi_stream [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $script_dir -vendor ucla.edu -library user -taxonomy {/UserIP} -import_files
set core [ipx::current_core]
set_property name chirp_axi_stream $core
set_property display_name {Chirp AXI-Stream Source} $core
set_property description {Configurable chirp source with AXI-Stream master output for JESD204B stimulation.} $core
set_property vendor_display_name {UCLA IT Services} $core
set_property version {1.0} $core

ipx::infer_bus_interface aclk xilinx.com:signal:clock_rtl:1.0 $core
ipx::infer_bus_interface aresetn xilinx.com:signal:reset_rtl:1.0 $core
ipx::infer_bus_interface m_axis xilinx.com:interface:axis_rtl:1.0 $core
ipx::associate_bus_interfaces -busif m_axis -clock aclk $core

set reset_busif [ipx::get_bus_interfaces aresetn -of_objects $core]
if {$reset_busif ne ""} {
  set_property POLARITY ACTIVE_LOW $reset_busif
}

ipx::save_core $core
close_project
