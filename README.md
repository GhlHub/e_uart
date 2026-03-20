# Enhanced UART

## Why design another UART?
<details>
<summary>Why did I design a UART?</summary>

If you are reading this, you might be wondering why would I bother to implement my own UART IP Core. There are plenty UART cores already out there free of charge. 

In order to understand why I designed my own UART, let’s take a walk down history. 
## UART History
When the IBM PC was first introduced back in 1981, the 8250 UART from National Semiconductor was used. As I recall this UART controller did not have a FIFO so it was important to service receive interrupts immediately so data isn’t lost. At that time this was a relatively easy since the baudrate was slow relative to the processor. Even in the mid 1980’s, 1200 baud was considered relatively fast. 

Fast forward a few years and in 1987 National Semiconductor release the 16550 Dual UART controller. This controller included 16 byte transmit and receive FIFOs which addressed the increasing baudrates and increasing interrupt latency due to increasing software complexity. This controller was quickly adopted by the PC industry and quickly became the de-facto standard UART controller we see today. In AMD/Xilinx Vivado tools there is a 16550 UART controller IP core that you can include in your FPGA design nearly 40 years after the 16550 was first introduced.

So that’s the history. I was a Computer Science Major in college, but I always had an interest in HDL design. So most of my elective courses were related to computer hardware design.

As the years passed, I always found myself twisting my code into a pretzel to account for the fact that these UARTs were designed in a time where there was no such thing as multicore processors, no concept of interrupt coalescing and no one knew what a Social Media Influencer is. 

It’s clear to me that the software interface of many UARTs really didn’t consider how a software engineer would really want to program and control the device in today’s environment. Add in the fact that many FPGA designs have unused FIFOs sitting around, it really made me wonder why should I bother with software queues for low data rate uart traffic when there are literally thousands of bytes of FIFO resources available, if only I had a UART controller that would used them.

On some more modern implementations of UARTs, they have byte by byte transmit complete interrupts but no transmit fifo empty interrupt. Or byte by byte receive interrupts but no receive fifo threshold interrupt. Or even worse receive threshold interrupts but without a timeout feature to interrupt the processor in the case where data has been received, but reception stopped short of the receive fifo threshold. This forces the microprocessor to poll the controller to get those received bytes out.
With the history of how we got here in terms of typical UART controller register interface I decided I would build a UART controller that worked in the way that was convenient for me to use. I came up with the following requirements.
</details>

## Design Requirements

- 1024-byte transmit and receive FIFOs 
- 8-bit or 32-bit access to the FIFOs
- Ability to retrieve the FIFO occupancy level
- Dynamically programmable baud
- Interrupt coalsecing
- Follow Vivado packaged IP methodology to facilitate integration with Microblaze, Zynq, Zynq UltraScale architecture. I will probably make a different version of this IP for Versal architecture. 

## Design Requirement Reasoning
### Transmit Data

- Large Transmit FIFO so transmits can be fire and forget. No need to manage transmit backpressure.
- 8/32-bit transmit data interface to give software the opportunity minimize bus transactions to send data.
- Visibility to Transmit FIFO occupancy vs *not-full-bit* allows write data loop optimization. Eliminates the need to read a *not-full-bit* after each data write.

### Receive Data

- Large Receive FIFO so the processor has time to read data and eliminate the possibility of dataloss.
- Programmable receive FIFO threshold **with** timeout feature so the software doesn’t have to poll UART for status.
- 8/32-bit receive data interface to give software the opportunity minimize bus transactions to receive data.
- Visibility to Receive FIFO occupancy vs *not-empty-bit* allows read data loop optimization. Eliminates the need to read a *not-empty-bit* after each data read.

# Theory of Operation

## UART Transmitter
- The Baud Rate Counter which is clocked by the AXI-S clock determines the time interval for a single bit.
- The host CPU initiates a transmit by writing a 8-bit byte or a 32-bit word to the Transmit FIFO.

When the Transmit FIFO is not empty, the transmit state machine in uart_tx.v will perform the following as long as the Transmit FIFO is not empty.
1. The transmit state machine will start sending the start bit by driving the TxD pin low. 
2. After the start bit is sent, the state machine will pop an 8-bit byte from the Transmit FIFO.
3. Each bit in the 8-bit byte is shifted out the TxD pin.
4. When the last bit is shifted out, the stop bit will be clocked out by driving TxD high.
5. After the stop bit is clocked out. We clock out an addition stop bit for 1/2 the time interval specified by the Baud Rate Counter by driving TxD high and leaving TxD high. I'm currently not sure if this additional "gap" is actually needed. If it's not needed, it's a simple change to the state machine. 

## UART Receiver
- The Oversample Rate Counter which is clocked by the AXI-S clock determines the time interval to sample the RxD pin.
- This UART receiver only supports 1 start-bit, 8 data-bits and pretty much ignores the stop-bit.
- RxD is oversampled at a rate of 5 times per bit. The samples are stored in a 45-bit shift register. (1 stop-bit, 8 data-bits = 9 bits. 9 bits * 5 samples per bit = 45-bits)

The receiver operates roughly as follows:
1. 45-bit shift register is initialized to all 1's
2. RxD samples is shifted in from the left. RxD_sample <= {RxD, RxD_sample[44:1]}
3. Look for RxD_sample[2:0] == 3'b001. This would indicate the beginning of the start-bit is at RxD[1].
4. Since the start-bit is roughly at RxD_sample[5:1]. Assume that RxD_sample[(5*z)+2], where z = 1 thru 9 are safe samples to use to assemble the byte and push the byte into the receive FIFO.
5. Delay for 45 Oversample Rate Counter time. Go to Step 2.

# Register Interface
## List of registers

Note: All registers are 32-bits wide.

| Offset  | Name | Description |
| ------------- | ------------- | - |
| 0x00 | Transmit Byte Register | Write 8-bit byte to TX FIFO  |
| 0x04 | Transmit Word Register | Write 32-bit word to TX FIFO  |
| 0x08 | Receive Byte Register | Read 8-bit byte from RX FIFO |
| 0x0c | Receive Word Register | Read 32-bit word from RX FIFO |
| 0x10 | Interrupt Status Register | |
| 0x14 | Interrupt Status Mask Register | |
| 0x18 | Config / Status Register | |
| 0x1c | Reserved | |
| 0x20 | Baud Rate Counter Register - BCR | AXI Clock Divisor for Transmit Baudrate |
| 0x24 | Oversample Rate Counter Register | AXI Clock Divisor for Receive oversampling rate |
| 0x28 | Interrupt Holdoff Register | Configures interrupt coalescing |
| 0x2c | Reserved | |
| 0x30 | Reserved | |
| 0x34 | Reserved | |
| 0x38 | Transmit FIFO Count Register | Number of bytes in TX FIFO | 
| 0x3c | Receive FIFO Count Register | Number of bytes in RX FIFO |

### Transmit Byte Register
| 31:8 | 7:0 |
| - | - |
| Ignored | Tx Byte |

The design has a single 1024-byte Transmit FIFO that is accessible from this register and the Transmit Word Register.

A write to this register writes one 8-bit byte to the Transmit FIFO.
Care should be taken not to overrun the Transmit FIFO as there are no checks in the design to detect or prevent this condition.

### Transmit Word Register
| 31:24 | 23:16 | 15:8 | 7:0 |
| - | - | - | - |
| Tx Byte 3 | Tx Byte 2 | Tx Byte 1 | Tx Byte 0 |

The design has a single 1024-byte Transmit FIFO that is accessible from this register and the Transmit Byte Register.

A write to this register writes four 8-bit bytes to the Transmit FIFO.
Care should be taken not to overrun the Transmit FIFO as there are no checks in the design to detect or prevent this condition.

### Receive Byte Register
| 31:8 | 7:0 |
| - | - |
| Reserved | Rx Byte |

The design has a single 1024-byte Receive FIFO that is accessible from this register and the Receive Word Register.

A read from this register reads one 8-bit byte from the receive FIFO.
Care should be taken not to underrun the Receive FIFO as there are no checks in the design to detect or prevent this condition.

### Receive Word Register
| 31:24 | 23:16 | 15:8 | 7:0 |
| - | - | - | - |
| Rx Byte 3 | Rx Byte 2 | Rx Byte 1 | Rx Byte 0 |

The design has a single 1024-byte Receive FIFO that is accessible from this register and the Receive Byte Register.

A read from this register reads four 8-bit bytes from the receive FIFO.
Care should be taken not to underrun the Receive FIFO as there are no checks in the design to detect or prevent this condition.

### Interrupt Status Register
| 31:5 | 4 | 3 | 2 | 1 | 0 |
| - | - | - | - | - | - |
| Reserved | Rx Time Coalesce Interrupt | Rx Byte Threshold Coalesce Interrupt | Rx FIFO Not Empty Interrupt | Tx Fifo Almost Empty Interrupt | Tx Empty Interrupt |

### Interrupt Mask Register
| 31:5 | 4 | 3 | 2 | 1 | 0 |
| - | - | - | - | - | - |
| Reserved | Rx Time Coalesce Interrupt Mask | Rx Byte Threshold Coalesce Interrupt Mask | Rx FIFO Not Empty Interrupt Mask | Tx Fifo Almost Empty Interrupt Mask | Tx Empty Interrupt Mask |

### Config / Status Register
| 31 | 30:2 | 1 | 0 |
| - | - | - | - |
| Irq_pin | Reserved | RxEn | TxEn |

- Irq_pin - Current state of the interrupt pin
- RxEn - Receive Enable
- TxEn - Transmit Enable

### Baudrate Counter Register - BCR
| 31:13 | 12:0 |
| - | - |
| Reserved | Tx Baudrate Divisor |

- Number of clock ticks minus one for a single bit at the desired baud rate in AXI-Clock units.
- Tx Baudrate Divisor = Round(AxiClockHz/BaudRate) - 1 

### Oversample Rate Counter Register
| 31:10 | 9:0 |
| - | - |
| Reserved | Rx Oversample Divisor |

- 1/5th the number of clock ticks minus 1 for a single bit at the desired baud rate in AXI-Clock units
- This is used to determine the sample time for the 5x oversampler.
- Rx Oversample Divisor = Round(AxiClockHz / (BuadRate * 5)) - 1
- Intended mode of operation is to program this register together with the Baudrate Counter Register so the transmit and receive logic are configured for the same effective baud rate.

### Interrupt Holdoff Register
| 31:27 | 26:16 | 15:11 | 10:0 |
| - | - | - | - |
| Reserved | Rx FIFO Byte Threshold Count | Reserved | Rx Byte Time Coalesce Count |

- Rx FIFO Byte Threshold Count - Number of bytes present in the Rx FIFO to trigger this interrupt
- Rx Byte Time Coalesce Count - Number of byte times elapsed after the first received byte to trigger this interrupt
- The intended mode of operation is for the transmit baudrate divisor and receive oversample divisor to be programmed together with values coherent to the TX and RX sides running at the same effective baud rate.
- The holdoff timeout counter intentionally uses the transmit baudrate divisor to measure elapsed byte times. With coherent programming, this produces the expected receive timeout behavior while keeping the holdoff logic simple.

### Transmit FIFO Count Register
| 31:11 | 10:0 |
| - | - |
| Reserved | Tx FIFO Occupancy |

Number of bytes present in the Tx FIFO.

### Receive FIFO Count Register
| 31:11 | 10:0 |
| - | - |
| Reserved | Rx FIFO Occupancy |

Number of bytes present in the Rx FIFO

## Areas that can be improved

### Split deisgn into two clock domains

- AXI side clock domain / UART clock domain
- Makes sense if the axi clock domain > 100 MHz
- Requires changing FIFOs to dual clock domain type

### Consider making a 64-bit varient to support 64-bit AXI Bus / processor support

- Add 64-bit wide registers for FIFO Read and FIFO Writes

