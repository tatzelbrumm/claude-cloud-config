# Give the final GDS its own top cell name (honor PROJECT)

Fixes the issue "make drc-final fails: top cell gf180mcu_ocd_chipalooza_final not found".

- `scripts/run_gen_filled_final_gds.sh`: `PROJECT` defaults to `gf180mcu_ocd_chipalooza_final`; fill output goes to a temporary file, then the top cell is renamed to `$PROJECT` and the file is written as `gds/$PROJECT.gds` (hashes and gzip use that name).
- `scripts/rename_top_cell.rb` (new): renames the top cell of a GDS with klayout.

Tested: the rename step on the existing filled GDS (top cell `gf180mcu_ocd_chipalooza_final`, 1030 cells).
Not tested: full `make gds-final` and `make drc-final` with the patch.

Apply with `git apply fix_final_top_cell.patch` from the repository root.
