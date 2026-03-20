# Agent Notes

## Repo purpose

This repository contains a Vivado-packaged AXI4-Lite UART IP core with:

- custom UART TX/RX RTL
- an AXI register block
- Vivado packaging metadata
- a small software driver
- self-checking simulation testbenches under `tb/`

## Important source files

- `hdl/e_uart.v`: packaged top-level wrapper
- `hdl/e_uart_slave_lite_v1_0_S00_AXI.v`: AXI4-Lite register interface and interrupt/status logic
- `src/uart_top.v`: UART integration logic
- `src/uart_tx.v`: transmitter
- `src/uart_rx.v`: receiver
- `src/int_holdoff.v`: RX interrupt coalescing / holdoff logic
- `drivers/e_uart_v1_0/src/e_uart.h`: software-visible register field definitions

## Verification flow

Primary regression entry point:

```bash
tb/run_xsim.sh all
```

Individual targets:

```bash
tb/run_xsim.sh int_holdoff_tb
tb/run_xsim.sh int_holdoff_axi_tb
```

Outputs are written under `out/xsim/<top>/` and include:

- `xvlog.log`
- `xelab.log`
- `xsim.log`
- `<top>.wdb`

## Testbench conventions

- Assume AXI clock is 50 MHz unless a test explicitly overrides it.
- Testbench log messages should print simulation time rounded to the nearest ns.
- Simulations should dump all waves.
- Existing holdoff coverage includes both direct-module and AXI-programmed interrupt holdoff tests.

## Project-specific cautions

- The AXI slave and driver must stay aligned on register field widths and shifts.
- RX holdoff timing is sensitive to exact threshold semantics; preserve equality-based trigger behavior.
- This repo contains generated Xilinx collateral. Avoid hand-editing generated IP output unless there is a clear reason.
- Do not assume there is complete end-to-end UART verification beyond the holdoff-focused testbenches already in `tb/`.
