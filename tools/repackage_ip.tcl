proc ensure_field {reg_obj field_name bit_offset bit_width access description} {
    set field_obj [ipx::get_fields $field_name -of_objects $reg_obj]
    if {$field_obj eq ""} {
        set field_obj [ipx::add_field $field_name $reg_obj]
    }
    set_property bit_offset $bit_offset $field_obj
    set_property bit_width $bit_width $field_obj
    set_property access $access $field_obj
    if {$description ne ""} {
        set_property description $description $field_obj
    }
    return $field_obj
}

proc ensure_register {addr_block name display_name description offset access fields} {
    set reg_obj [ipx::get_registers $name -of_objects $addr_block]
    if {$reg_obj eq ""} {
        set reg_obj [ipx::add_register $name $addr_block]
    }
    set_property display_name $display_name $reg_obj
    set_property description $description $reg_obj
    set_property address_offset $offset $reg_obj
    set_property size 32 $reg_obj
    set_property access $access $reg_obj
    foreach field_def $fields {
        lassign $field_def field_name bit_offset bit_width field_access field_desc
        ensure_field $reg_obj $field_name $bit_offset $bit_width $field_access $field_desc
    }
    return $reg_obj
}

set root_dir [file normalize [file dirname [info script]]/..]
if {[info exists ::env(E_UART_COMPONENT_XML)] && $::env(E_UART_COMPONENT_XML) ne ""} {
    set component_path [file normalize $::env(E_UART_COMPONENT_XML)]
} else {
    set component_path [file join $root_dir component.xml]
}

puts "Opening IP core: $component_path"
set core [ipx::open_core $component_path]

set memory_map [ipx::get_memory_maps S00_AXI -of_objects $core]
set addr_block [ipx::get_address_blocks S00_AXI_reg -of_objects $memory_map]

ensure_register $addr_block TX_BYTE_FIFO "Transmit Byte Register" \
    "Write one byte to the transmit FIFO. Readback returns the last written byte value." \
    0x000 read-write {
        {TX_BYTE 0 8 read-write "Transmit byte value"}
    }

ensure_register $addr_block TX_WORD_FIFO "Transmit Word Register" \
    "Write four bytes to the transmit FIFO. Byte 0 is transmitted first." \
    0x004 read-write {
        {TX_WORD 0 32 read-write "Transmit word value"}
    }

ensure_register $addr_block RX_BYTE_FIFO "Receive Byte Register" \
    "Read one byte from the receive FIFO." \
    0x008 read-only {
        {RX_BYTE 0 8 read-only "Receive byte value"}
    }

ensure_register $addr_block RX_WORD_FIFO "Receive Word Register" \
    "Read four bytes from the receive FIFO. Byte 0 is returned in bits 7:0." \
    0x00C read-only {
        {RX_WORD 0 32 read-only "Receive word value"}
    }

ensure_register $addr_block INT_STATUS "Interrupt Status Register" \
    "Current interrupt status bits. RX_TIME_COALESCE is write-1-to-clear." \
    0x010 read-write {
        {TX_EMPTY 0 1 read-only "Transmit FIFO empty interrupt status"}
        {TX_FIFO_ALMOST_EMPTY 1 1 read-only "Transmit FIFO almost empty interrupt status"}
        {RX_FIFO_NOT_EMPTY 2 1 read-only "Receive FIFO not empty interrupt status"}
        {RX_BYTE_THRESHOLD 3 1 read-only "Receive FIFO byte threshold interrupt status"}
        {RX_TIME_COALESCE 4 1 read-write "Receive timeout coalescing interrupt status. Write 1 to clear."}
    }

ensure_register $addr_block INT_MASK "Interrupt Mask Register" \
    "Interrupt mask bits corresponding to INT_STATUS." \
    0x014 read-write {
        {TX_EMPTY_MASK 0 1 read-write "Mask for transmit FIFO empty interrupt"}
        {TX_FIFO_ALMOST_EMPTY_MASK 1 1 read-write "Mask for transmit FIFO almost empty interrupt"}
        {RX_FIFO_NOT_EMPTY_MASK 2 1 read-write "Mask for receive FIFO not empty interrupt"}
        {RX_BYTE_THRESHOLD_MASK 3 1 read-write "Mask for receive FIFO byte threshold interrupt"}
        {RX_TIME_COALESCE_MASK 4 1 read-write "Mask for receive timeout coalescing interrupt"}
    }

ensure_register $addr_block CTRL_STATUS "Config / Status Register" \
    "Control bits for TX/RX enable and current interrupt pin status." \
    0x018 read-write {
        {TX_EN 0 1 read-write "Transmit enable"}
        {RX_EN 1 1 read-write "Receive enable"}
        {IRQ_PIN 31 1 read-only "Current interrupt pin state"}
    }

ensure_register $addr_block BAUDRATE_COUNTER "Baud Rate Counter Register" \
    "Transmit baud rate divisor in AXI clock cycles minus one." \
    0x020 read-write {
        {TX_BAUD_DIVISOR 0 13 read-write "Transmit baud divisor"}
    }

ensure_register $addr_block OVERSAMPLE_COUNTER "Oversample Rate Counter Register" \
    "Receive oversample divisor for the 5x receiver sampling clock." \
    0x024 read-write {
        {RX_OVERSAMPLE_DIVISOR 0 10 read-write "Receive oversample divisor"}
    }

ensure_register $addr_block INT_HOLDOFF "Interrupt Holdoff Register" \
    "RX interrupt coalescing thresholds. Program coherently with the transmit baud divisor so TX and RX operate at the same effective baud rate." \
    0x028 read-write {
        {RX_BYTE_TIME_COALESCE_COUNT 0 11 read-write "Receive byte-time coalescing count"}
        {RX_FIFO_BYTE_THRESHOLD_COUNT 16 11 read-write "Receive FIFO byte threshold count"}
    }

ensure_register $addr_block TX_FIFO_COUNT "Transmit FIFO Count Register" \
    "Current number of bytes in the transmit FIFO." \
    0x038 read-only {
        {TX_FIFO_OCCUPANCY 0 11 read-only "Transmit FIFO occupancy"}
    }

ensure_register $addr_block RX_FIFO_COUNT "Receive FIFO Count Register" \
    "Current number of bytes in the receive FIFO." \
    0x03C read-only {
        {RX_FIFO_OCCUPANCY 0 11 read-only "Receive FIFO occupancy"}
    }

puts "Running integrity check"
ipx::check_integrity -quiet $core

if {![catch {ipx::update_checksums $core} checksum_msg]} {
    puts "Updated package checksums"
} else {
    puts "Checksum refresh not supported in this flow: $checksum_msg"
}

puts "Saving IP core"
ipx::save_core $core

puts "Repackage complete"
exit 0
