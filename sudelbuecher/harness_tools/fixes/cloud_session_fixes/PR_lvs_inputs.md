# validate: read the SRAM netlist from the PDK .spice path

`validate/run_lvs_ocd_chipalooza.sh` read the SRAM netlist from `libs.ref/gf180mcu_ocd_ip_sram/cdl/...cdl`, which the installed PDK does not have. Read `libs.ref/gf180mcu_ocd_ip_sram/spice/...spice` instead (patch: lvs_sram_spice_path.patch; apply with `git apply` from the repo root).
Tested: netgen gets past this read. Not tested: a complete LVS (it later fails on the pad pin names, see the issue). The missing `netlist/schematic/gf180mcu_ocd_io.spice` is a separate item in the issue.
