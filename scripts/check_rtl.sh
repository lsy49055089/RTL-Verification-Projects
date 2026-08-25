#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
out_dir="$(mktemp -d)"

iverilog -g2012   -s top_spi_loopback   -o "$out_dir/spi.out"   "$repo_root"/uvm-spi-i2c-verification/rtl/spi/*.sv

iverilog -g2012   -s top_i2c   -o "$out_dir/i2c.out"   "$repo_root"/uvm-spi-i2c-verification/rtl/i2c/*.sv

iverilog -g2012   -s uart_fifo_loopback_sv   -o "$out_dir/uart_fifo.out"   "$repo_root"/systemverilog-uart-fifo-verification/dut/*.sv

echo "PASS: SPI, I2C, and UART/FIFO DUT elaboration"
