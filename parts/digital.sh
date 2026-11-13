# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# ---- optional: the digital simulation tools of the Chipalooza mixed-signal path (make-setup.sh <pdk> digital) ----
# Installs Icarus Verilog, Yosys, Verilator and cocotb. Distro versions, NOT the IIC-OSIC-TOOLS pins.
# NOT included: LibreLane / OpenROAD (no prebuilt archive yet) -- run the digital hardening flow in the local container.
# Sits between the PDK part and main.sh, because main.sh ends with `exit 0`. Runs in the foreground (about 25 s).
( apt-get update -qq && apt-get install -y -qq --no-install-recommends iverilog yosys verilator make \
    && pip install -q --break-system-packages cocotb \
    && ok DIGITAL ) >> $L 2>&1
