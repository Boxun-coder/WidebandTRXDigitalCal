set project_name ads7_ad9164_custom
set project_dir [file normalize [file join [file dirname [info script]] vivado $project_name]]
set impl_dcp    [file join $project_dir ${project_name}.runs impl_1 system_top_routed.dcp]
set synth_dcp   [file join $project_dir ${project_name}.runs synth_1 system_top.dcp]

proc pick_checkpoint {impl_dcp synth_dcp} {
  if {[file exists $impl_dcp]} {
    return $impl_dcp
  }
  if {[file exists $synth_dcp]} {
    return $synth_dcp
  }
  error "No synthesized or implemented checkpoint was found."
}

proc first_net {patterns} {
  foreach pattern $patterns {
    set nets [get_nets -quiet -hier -regexp $pattern]
    if {[llength $nets] > 0} {
      return [lindex $nets 0]
    }
  }
  return ""
}

proc add_probe_if_present {core index patterns width} {
  set net_name [first_net $patterns]
  if {$net_name eq ""} {
    puts "WARNING: unable to locate probe $index for patterns '$patterns'"
    return
  }
  create_debug_port $core probe
  set probe_name ${core}/probe${index}
  set_property port_width $width [get_debug_ports $probe_name]
  connect_debug_port $probe_name [get_nets $net_name]
}

open_checkpoint [pick_checkpoint $impl_dcp $synth_dcp]

create_debug_core u_ila_jesd ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_jesd]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_jesd]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_jesd]

set ila_clk [first_net {
  {.*ila_chirp_tvalid.*}
  {.*microblaze_0_clk.*}
  {.*sys_clk.*}
}]
if {$ila_clk eq ""} {
  error "Unable to find a suitable ILA clock."
}
connect_debug_port u_ila_jesd/clk [get_nets $ila_clk]

add_probe_if_present u_ila_jesd 0 {{.*ila_sync.*}} 1
add_probe_if_present u_ila_jesd 1 {{.*ila_sysref.*}} 1
add_probe_if_present u_ila_jesd 2 {{.*ila_chirp_marker.*}} 1
add_probe_if_present u_ila_jesd 3 {{.*ila_chirp_tvalid.*}} 1
add_probe_if_present u_ila_jesd 4 {{.*ila_chirp_tdata\[.*\].*} {.*dbg_chirp_tdata.*}} 16
add_probe_if_present u_ila_jesd 5 {{.*jesd204_tx_0.*(ready|resetdone).*}} 1
add_probe_if_present u_ila_jesd 6 {{.*jesd204_tx_0.*(tx_tready|s_axis_tready).*}} 1
add_probe_if_present u_ila_jesd 7 {{.*jesd204_tx_0.*(sync|sysref).*}} 1

write_debug_probes -force [file join [file dirname [info script]] ads7_ad9164_custom.ltx]
write_checkpoint -force [file join [file dirname [info script]] ads7_ad9164_custom_debug.dcp]

puts "ILA checkpoint and probe file generated."
