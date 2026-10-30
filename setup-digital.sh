#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# Add-on for setup-cloud.sh (Ubuntu 24.04 x86_64): the digital simulation tools of the Chipalooza mixed-signal path.
# Installs Icarus Verilog, Yosys, Verilator and cocotb. Distro versions, NOT the IIC-OSIC-TOOLS pins.
# NOT included: LibreLane / OpenROAD (no prebuilt archive yet) -- run the digital hardening flow in the local container.
# Run it AFTER setup-cloud.sh, in the same Setup script (append the two files). Must exit 0. Log: /foss/setup.log
export DEBIAN_FRONTEND=noninteractive
L=/foss/setup.log; mkdir -p /foss; t0=$(date +%s)
( apt-get update -qq && apt-get install -y -qq --no-install-recommends iverilog yosys verilator make \
    && pip install -q --break-system-packages cocotb \
    && echo "DIGITAL_OK $(( $(date +%s) - t0 ))s" >> $L ) >> $L 2>&1
exit 0
