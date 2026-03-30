set script_dir [file dirname [file normalize [info script]]]
set ip_root [file join $script_dir ip_repo e_uart]
set component_xml [file join $ip_root component.xml]
set template_component_xml [file join $script_dir .component_xml.template]

if {![file exists $component_xml]} {
    puts stderr "ERROR: Expected packaged template at $component_xml"
    exit 1
}

file copy -force $component_xml $template_component_xml

file delete -force $ip_root
file mkdir $ip_root

foreach item {bd drivers hdl src xgui} {
    file copy -force [file join $script_dir $item] [file join $ip_root $item]
}
file copy -force $template_component_xml $component_xml
file delete -force $template_component_xml

set ::env(E_UART_COMPONENT_XML) $component_xml
source [file join $script_dir tools repackage_ip.tcl]
