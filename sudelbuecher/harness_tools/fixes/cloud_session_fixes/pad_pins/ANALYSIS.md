<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# iovdd/iovss pad pin names in the Chipalooza padframe verilog: analysis and patch

**Written by an Opus 5.5 (Medium effort) subagent of the planning session, 2026-11-23. The planning session saved the agent's report here
as the agent wrote it (the agent could not write the file itself) and added the "Checked by the planning session" section. Not a chat
log.** Base: harness main `78edf00` (user's fork = upstream `d5ad122` plus a merge). PDK gf180mcuD (open_pdks `e7a6777`).
Evidence: the cloud build's `lvs-top2.log` (fork branch `chipalooza_logs`, run `20261123T0029Z`) and its output tree.

## Summary
**Root cause:** `scripts/gf180mcu_padframe_template.v` came over from the IHP harness. The cell names were ported, but every pad
instance still uses the IHP power pins `.iovdd/.iovss/.vdd/.vss`. `parse_config.py` copies those blocks through unchanged into
`verilog/gl/gf180mcu_padframe.v`. `vdd/vss` only pass because netgen switches to case-insensitive matching. The splitter
`gf180mcu_ocd_Split200` is also IHP-only and becomes a netgen placeholder.

**Mapping:** iovdd->DVDD, iovss->DVSS, vdd->VDD, vss->VSS. Confidence high. In the GF spice, DVDD/DVSS feed the 6 V drivers and pad ESD
(the 5 V I/O ring), and VDD/VSS feed the 3.3 V side of the level shifters (the core). The LEF and the extracted layout use the same
names. The nets themselves are already right; only names change. The splitter becomes `gf180mcu_ocd_io__brk5 (.VSS(vss3v3))`,
matching the layout.

**Patch files:**
- `pad_pins.patch`: the template plus the regenerated `verilog/gl/gf180mcu_padframe.v`.
- Optional `lvs_scripts.patch`: in `validate/run_lvs_ocd_chipalooza.sh` and `validate/run_lvs_padframe.sh` it removes the IHP
  `flatten gf180mcu_SecondaryProtection` lines, which made netgen abort. It also falls back to the PDK I/O spice when the custom
  netlist is missing from the repo.

**Verified (by the agent):**
- netgen pin errors went from 452 to 0.
- A full `run_lvs_ocd_chipalooza.sh` on a copy of the cloud tree now runs to the end. The padframe has 189/189 devices; the remaining
  differences are all supply nets. The final result is still "Netlists do not match", including "vss3v3 and vss5v0 shorted" (the
  README ground-domain issue).
- Locally the SRAM had to be read from its `.spice` view, because the `.cdl` is not installed here.

**Cloud colleague:** apply both patches, then run `make lvs-top` (optionally `make extract-padframe lvs-padframe`).

**Open points:**
- The custom `netlist/schematic/gf180mcu_ocd_io.spice` is missing, so its pin names are unchecked.
- The verilog's filler cells (IHP counts) don't match the layout's fill10/fill5/fill1 cells.
- In the extracted layout the upper-ring rails merge into `VSUBS`. The bottom-segment DVSS has no pad.
- `gen_padframe_template.tcl` lines 1076-1077 label two `dvss` pads `vdd5v0`; this looks like a bug.
- `lvs-padframe` was not run.

## Root cause
Cells were renamed per porting.txt lines 43-52, but the power pins in the template were not. `parse_config.py` writes no pad power
pins: lines 165-249 only substitute the TYPE/PAD/SIGNALS tokens. So the template's `ifdef USE_POWER_PINS` blocks reach the gl file
unchanged. That gives 452 errors (226 instance bits x 2) plus 452 implicit DVDD/DVSS pins. lvs-top2.log line 1285 shows netgen's
case-insensitive fallback.

## 1. Occurrences
**Source, fixed:** `scripts/gf180mcu_padframe_template.v`. 88 pad instances or arrays, lines 107-1192. The splitter
`gf180mcu_ocd_Split200` is at line 145 with `.iovdd/.iovss/.vssl`. The `constant_block` `.vdd/.vss` pins are the module's own names and
are correct.

**Generated, regenerated:** `verilog/gl/gf180mcu_padframe.v` (178 occurrences; splitter line 180, spacers lines 1193-1228), from
`make config` (`parse_config.py`).

**Left alone:**
- `archive/gf180mcu_padframe.v`: backup made by run_clean.sh, identical to the gl file, not used by any flow.
- `validate/comp_gf180mcu_padframe.out` and `validate/comp_gf180mcu_ocd_chipalooza.out`: stale IHP-era LVS reports (they mention
  sg13g2_SecondaryProtection at lines 684 and 2001). The next lvs run overwrites them.

**No pad pin names:**
- `gen_padframe_template.tcl` and `gen_padframe.tcl` label by net name.
- `chipalooza_frame_wrapper_template.v` and its generated wrapper.
- xschem files.
- `parse_config.py`, apart from a dead `CONSTANT_BLOCKS` branch (lines 300-320) that would emit `vccd/vssd`. That token is not in the template.

**Not pad pins:** `IOVDD_IN/IOVDD_OUT/IOVSS` belong to the harness's own `power_stage` cell. They appear in
`verilog/rtl/chipalooza_frame.v` 899-903, the netlist spice files, `validate/lvs/*` and `check_polarity.py`, and are consistent
between schematic and layout.

**Other IHP leftovers in the LVS path:**
- The Split200 placeholder (log line 1302). The layout has brk5 at these positions (tcl lines 314/353/472/530; extracted as
  `Xspacer_17j` and `Xspacer_82j`).
- The `flatten gf180mcu_SecondaryProtection` lines in `run_lvs_ocd_chipalooza.sh` 64-65 and `run_lvs_padframe.sh` 37-38. netgen aborts
  there (log lines 2310-2314).
- The missing `netlist/schematic/gf180mcu_ocd_io.spice` (the first lvs-top run failed on it).

## 2. Pins per cell
| Cell | Instances | PDK verilog (= spice = layout) pins |
|---|---|---|
| cor | 4 | DVDD DVSS VDD VSS |
| bi_24t | 13 | CS SL IE OE PU PD A PAD Y DVDD DVSS VDD VSS |
| in_c | 4 | PU PD PAD Y + 4 rails |
| asig_5p0 | 40 | ASIG5V + 4 rails |
| vdd, vss, dvdd, dvss | 7 / 7 / 3 / 6 | 4 rails |
| fill5, fill1 | arrays | 4 rails |
| brk5 | splitter | VSS only |

Signal pins were already correct. Every instance connected iovdd/iovss/vdd/vss.

Evidence for the role of each rail:
- `io_out_24` and its predriver inverters sit on DVDD/DVSS with 06v0 devices (spice lines 46-75). The pad ESD diodes go to DVDD/DVSS.
- The dvdd/dvss pad cells clamp DVDD-DVSS and leave VDD/VSS noconn (lines 633-688).
- `io_lvlshft DVDD VDD IN OUT VSS DVSS` (line 197) has its input on VDD/VSS with 03v3 devices. The core input clamps in bi_24t go to VDD.
- The vdd/vss pad cells clamp VDD-VSS (lines 891-945).
- LEF: DVDD and VDD are USE POWER; DVSS and VSS are USE GROUND.

This matches IHP's iovdd/iovss = I/O ring and vdd/vss = core. The IHP side is from general knowledge; no IHP PDK is installed here.
Confidence is high.

## 3. Nets
No net changes are needed. DVDD->vdd5v0, DVSS->vss5v0, VSS->vss3v3. VDD->vddd on exactly the bottom segment between the two brk5
cells: corners sw/se, SDO, gpio0-7, the in_c pads, pad_vddd_0/1, pad_vdd5v0_0, pad_vss3v3_6 and spacer5b/1b. Elsewhere VDD->vdd3v3.
This is consistent with the layout generator.

Ground-domain issue, kept separate: after the patch the padframe compares 189/189 devices, with nets 251 vs 252.
- The layout shorts vss3v3 to vss5v0.
- The extracted upper-ring rails all merge into VSUBS.
- The bottom-segment DVSS is unnamed (`pad_clk/DVSS`). brk5 cuts DVDD, DVSS and VDD, and that segment has no dvss pad.
- tcl lines 1076-1077 label the dvss pads pad_vss5v0_2/3 as `vdd5v0`. This is a suspected bug and unverified.

## 4. Patch and regeneration
`tools/rename_pad_pins.py` made 352 renames; the splitter was changed to brk5 `.VSS(vss3v3)` by hand.

Regenerate with `rm verilog/gl/gf180mcu_padframe.v verilog/gl/chipalooza_frame_wrapper.v scripts/gen_padframe.tcl && ./scripts/parse_config.py`.
`make clean-config` would also move `magic/*.mag` into archive/.
- Regeneration from the unmodified template is byte-identical to the committed files.
- After the patch, the wrapper and gen_padframe.tcl come out unchanged, so no layout regeneration is needed.
- `git apply --check` passes on the clone, and `patch -p1` applies to the tree copy.

Rerun in the cloud: both patches, then `make lvs-top` (extract-top output already exists), optionally `make extract-padframe lvs-padframe`.
Expect 0 pin errors and a final "do not match" from the ground-domain issue.

## Unverified
- The pins of the custom gf180mcu_ocd_io.spice.
- The filler population: verilog has fill5 x72 and fill1 x70; layout has fill10 x835, fill5 x82, fill10x x17 plus fill1. LVS survives
  only because fillers are empty or black boxes.
- `lvs-padframe` was not run, because there is no extracted padframe spice.
- The brk5 VSS net (vss3v3) is inferred; its schematic marks VSS noconn, so LVS cannot check it.

## Checked by the planning session
On a fresh copy of the harness at `78edf00`: `git apply --check` passes for `pad_pins.patch`, then for `lvs_scripts.patch` on top. After
both, `verilog/gl/gf180mcu_padframe.v` has 0 `.iovdd(`/`.iovss(` left, 176 `.DVDD(`/`.DVSS(` and 12 `.vdd(`/`.vss(` (the
`constant_block` module's own pins). The rest of the agent's numbers (452 -> 0, 189/189, "Netlists do not match") are the agent's and
not re-run by the planning session; see `verify.log`, `lvs-top-patched.log` and `comp_gf180mcu_ocd_chipalooza.patched.out`.
