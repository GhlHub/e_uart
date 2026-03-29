set script_dir [file dirname [file normalize [info script]]]
set ip_root [file join $script_dir ip_repo e_uart]
set component_xml [file join $ip_root component.xml]

file delete -force $ip_root
file mkdir $ip_root

foreach item {bd drivers hdl src xgui component.xml} {
    file copy -force [file join $script_dir $item] [file join $ip_root $item]
}

set ::env(E_UART_COMPONENT_XML) $component_xml
source [file join $script_dir tools repackage_ip.tcl]
