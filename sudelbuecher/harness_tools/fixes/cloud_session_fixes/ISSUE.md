# make drc-final fails: top cell "gf180mcu_ocd_chipalooza_final" not found

## Problem
After `make gds-final`, `make drc-final` stops with

    ERROR: ... 'source': Cell name gf180mcu_ocd_chipalooza_final not found in input layout

(`validate/run_klayout_drc_final.sh` and the other harness scripts always exit 0, so `make` reports success and no `.lyrdb` is written.)

## Cause
`gds/gf180mcu_ocd_chipalooza_final.gds.gz` has the top cell `gf180mcu_ocd_chipalooza` (1030 cells; the pre-fill GDS has the same top cell, 1016 cells).
`scripts/run_gen_filled_final_gds.sh` runs only `fill_all.rb`, which adds the fill cells to the existing top cell and writes the file under the new name; it never renames the top cell.
The README (step 10) and `validate/run_klayout_drc_final.sh` (`PROJECT=${PROJECT:-gf180mcu_ocd_chipalooza_final}`, `-rd topcell=${PROJECT}`) expect a top cell named `$PROJECT`, default `gf180mcu_ocd_chipalooza_final`.

Regression from bf1d19b ("correction to the fill generation method"): the previous magic-based script created a new top cell named `$PROJECT`, honoring the environment variable for GF shuttle submissions (e.g. `GF__MPC9763`). The klayout version dropped that, so `PROJECT` no longer has any effect on `make gds-final`.

## Fix
See the pull request: honor `PROJECT` (default `gf180mcu_ocd_chipalooza_final`) in `run_gen_filled_final_gds.sh` and rename the top cell after fill with a small klayout script (`scripts/rename_top_cell.rb`). The rename was tested on the existing final GDS: top cell `gf180mcu_ocd_chipalooza_final`, 1030 cells.
Not tested: a full `make gds-final` rerun and `make drc-final` with the patch.
