# make lvs-top: two input files do not exist in a fresh checkout / the installed PDK

Found while building the harness in a clean container (PDK /foss/pdks gf180mcuD, harness main @ 78edf00).

## 1. netlist/schematic/gf180mcu_ocd_io.spice is not in the repository
`validate/run_lvs_ocd_chipalooza.sh` line 19 reads `../netlist/schematic/gf180mcu_ocd_io.spice`; the file is in no commit.
Line 20 (commented out) shows the PDK copy as the alternative. Netgen aborts after 1 s: `Error in SPICE file read: No file ../netlist/schematic/gf180mcu_ocd_io.spice`.
Workaround used (not a repo change): `cp $PDK_ROOT/$PDK/libs.ref/gf180mcu_ocd_io/spice/gf180mcu_ocd_io.spice netlist/schematic/`.
Suggested fix: read the PDK copy directly (use the commented line 20), or generate/commit the file.

## 2. SRAM netlist path: PDK ships .spice, not .cdl
Line 45 reads `$PDK_ROOT/$PDK/libs.ref/gf180mcu_ocd_ip_sram/cdl/gf180mcu_ocd_ip_sram__sram1024x8m8wm1.cdl`. The installed PDK has only `.../spice/gf180mcu_ocd_ip_sram__sram1024x8m8wm1.spice` (no cdl directory).
Netgen aborts: `Error in SPICE file read: No file .../cdl/...cdl`.
Fix: see lvs_sram_spice_path.patch (one-line path change). The script's comment says the SRAM contents are not compared (abstract view), so only the port list matters.
Not tested: whether the CDL in other PDK installs differs from the .spice in port order or content.

## After both are in place
Netgen now reads all inputs and stops with 452 `Instance ... has pin iovdd/iovss which is not in the gf180mcu_ocd_io__* cell definition` errors (pad and spacer instances) and aborts at netgen.tcl line 52. That is a separate problem (padframe verilog uses IHP pin names); no comp.out is produced. Tracked separately.
