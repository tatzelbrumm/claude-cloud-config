# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
# Abutment box of every pad cell of gf180mcu_ocd_io, the way the harness reads it (scripts/gen_padframe_template.tcl:
# getcell, identify, `instance list abutment`). An empty box on the FIRST call after getcell is the symptom of stale child
# timestamps in the pad views (notes/2026-11-19_gf180_harness_handoff.md). Needs the box set before getcell.
# usage: PDK_ROOT=... PDK=gf180mcuD magic -dnull -noconsole -rcfile $PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc pad_abutment_check.tcl
# Prints ABUT <cell>: <box> per pad and ABUT_SUMMARY pads <n> empty <n> <names>.
drc off
crashbackups stop
set n 0; set empty {}
foreach f [lsort [glob $env(PDK_ROOT)/$env(PDK)/libs.ref/gf180mcu_ocd_io/mag/gf180mcu_ocd_io__*.mag]] {
    set c [file rootname [file tail $f]]
    load abut_test_$n
    box values 0 0 0 0
    getcell $c
    identify pad_$n
    set a [instance list abutment pad_$n]
    if {[string trim $a] eq ""} {lappend empty $c}
    puts "ABUT $c: $a"
    incr n
}
puts "ABUT_SUMMARY pads $n empty [llength $empty] $empty"
quit -noprompt
