# Chipalooza cloud build report
Model claude-sonnet-5-5, effort medium. PDK gf180mcuD, Magic 8.3.706, 4 cores, 15 GB.
`make setup` does not exist (scripts/setup.sh missing in repo); skipped on user's instruction.

| step | rc | s | result judged by log/output |
|---|---|---|---|
| check | 0 | 0 | 0 stale, 1 not built (validate/lvs/comp.out) |
| submodules | 0 | 2 | 3 dependencies filled |
| pad abutment | - | - | ABUT_SUMMARY pads 17 empty 0 (OK). addpath: fd_io listed before ocd_io (lines 47, 50) |
| clean-config, config, padframe, wrappers, symbols, gds-slots, user-id | 0 | 0-5 | ok (logs not grepped) |
| projects-gds | 0 | 7 | no project assigned in 18 slots, 0 placed |
| gds-prefill | 0 | 159 | file written; SRAM "placed on top of itself" warnings |
| gds-final | 0 | 68 | file written; top cell NOT renamed |
| drc-final | 0 | 3 | FAILED: cell gf180mcu_ocd_chipalooza_final not found; no .lyrdb |
| extract-sch-top | 0 | 0 | netlist/schematic spice written |
| extract-top | 0 | 1621 | netlist/layout spice written; 3 port-short warnings |
| lvs-top | 0 | 1 | FAILED: No file ../netlist/schematic/gf180mcu_ocd_io.spice; no comp.out |

Cause of drc-final failure: bf1d19b replaced the magic compositor with fill_all.rb, which keeps the top cell name; fix and issue text in the artifacts branch fixes/.
Sizes: final GDS gz 33.1 MB, xz pack 23.7 MB, 1 chunk; prefill 22.8 MB. cells.tsv from the final GDS (top cell unrenamed).
Artifacts branch: final GDS pack, mag_files.tar.xz, prefill+slot GDS tar, fixes/, cells.tsv.
