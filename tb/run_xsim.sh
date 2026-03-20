#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLOW_DIR="$ROOT_DIR/tb/xsim"
OUT_DIR="$ROOT_DIR/out/xsim"

XVLOG="${XVLOG:-/tools/Xilinx/2025.2/Vivado/bin/xvlog}"
XELAB="${XELAB:-/tools/Xilinx/2025.2/Vivado/bin/xelab}"
XSIM="${XSIM:-/tools/Xilinx/2025.2/Vivado/bin/xsim}"

usage() {
    cat <<'EOF'
Usage: tb/run_xsim.sh [int_holdoff_tb|int_holdoff_axi_tb|all]

Runs the requested xsim verification target and logs all waves into a .wdb.
Results are written under out/xsim/<top>/.
EOF
}

run_tb() {
    local top="$1"
    shift

    local build_dir="$OUT_DIR/$top"

    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    pushd "$build_dir" >/dev/null

    "$XVLOG" --sv --work xil_defaultlib "$@"
    "$XELAB" --debug typical --relax --timescale 1ns/1ps \
        -s "${top}_sim" "xil_defaultlib.${top}"
    "$XSIM" "${top}_sim" \
        -tclbatch "$FLOW_DIR/run_all_waves.tcl" \
        -wdb "${top}.wdb"

    popd >/dev/null
}

TARGET="${1:-all}"

case "$TARGET" in
    int_holdoff_tb)
        run_tb \
            int_holdoff_tb \
            "$ROOT_DIR/src/int_holdoff.v" \
            "$ROOT_DIR/tb/int_holdoff_tb.sv"
        ;;
    int_holdoff_axi_tb)
        run_tb \
            int_holdoff_axi_tb \
            "$ROOT_DIR/src/int_holdoff.v" \
            "$ROOT_DIR/hdl/e_uart_slave_lite_v1_0_S00_AXI.v" \
            "$ROOT_DIR/tb/int_holdoff_axi_tb.sv"
        ;;
    all)
        bash "$0" int_holdoff_tb
        bash "$0" int_holdoff_axi_tb
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
