set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set out_dir [file join $repo_root out util]

file mkdir $out_dir

create_project -in_memory -part xc7z020clg400-1
set_msg_config -id {Synth 8-7080} -new_severity {INFO}

read_ip [file join $repo_root src fifo_generator_0 fifo_generator_0.xci]
generate_target all [get_ips fifo_generator_0]

read_verilog [list \
    [file join $repo_root hdl e_uart.v] \
    [file join $repo_root hdl e_uart_slave_lite_v1_0_S00_AXI.v] \
    [file join $repo_root src uart_top.v] \
    [file join $repo_root src uart_tx.v] \
    [file join $repo_root src uart_rx.v] \
    [file join $repo_root src int_holdoff.v]]

synth_design -top e_uart -part xc7z020clg400-1 -mode out_of_context

report_utilization -file [file join $out_dir e_uart_utilization.rpt]
report_utilization -hierarchical -hierarchical_percentages -file [file join $out_dir e_uart_utilization_hier.rpt]
report_timing_summary -file [file join $out_dir e_uart_timing_summary.rpt]

puts "Wrote utilization reports to $out_dir"
