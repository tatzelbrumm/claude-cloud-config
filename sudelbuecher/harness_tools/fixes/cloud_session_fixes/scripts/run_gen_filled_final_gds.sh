#!/bin/bash
#
# Run the klayout fill generation on the top level chip to produce
# the final design to submit to Wafer.Space.
#
# This script is assumed to be run in the magic/ directory, as it
# cds up one directory level and then down to gds/.  It could be
# made smarter about this.

# NOTE:  If PROJECT is set as an environment variable, then the final
# top level cell name and GDS file name will be set to its value.  If
# not, then the default top level name is "gf180mcu_ocd_chipalooza_final".
# When submitting for a GF shuttle run, the project name will be dictated
# by the GF submission process (e.g., PROJECT=GF__MPC9763).
# The fill script keeps the name of the input top cell, so the top cell
# is renamed afterwards;  "make drc-final" and the final extraction and LVS
# look for the cell and file named ${PROJECT}.

export PROJECT=${PROJECT:-gf180mcu_ocd_chipalooza_final}
export PDK_ROOT=${PDK_ROOT:-/usr/share/pdk}
export PDK=${PDK:-gf180mcuD}

echo "Generating final (filled) GDS for $PROJECT"

cd ../gds

# Some designs have a requirement for flag "Metal2_ignore_active", or
# else the GF fill rules will not allow density to be met.  This may
# not be necessary for the harness chip because much of the user
# project areas is unused and is pure fill.

# NOTE: Wafer.Space requires file hashes for validation, but the hashes
# must be run on the *uncompressed* GDS.  So generate uncompressed GDS
# output, print the hash values, then compress the final GDS for tapeout.

klayout -zz -r \
    ${PDK_ROOT}/gf180mcuD/libs.tech/klayout/tech/scripts/fill_all.rb \
    -rd input=gf180mcu_ocd_chipalooza.gds.gz \
    -rd output=${PROJECT}_fill.gds || exit 1

# Give the filled layout its own top level cell name
klayout -zz -r ../scripts/rename_top_cell.rb \
    -rd input=${PROJECT}_fill.gds \
    -rd output=${PROJECT}.gds \
    -rd newname=${PROJECT} || exit 1
rm -f ${PROJECT}_fill.gds

echo "md5sum:"
md5sum ${PROJECT}.gds

echo "sha1sum:"
sha1sum ${PROJECT}.gds

echo "sha256sum:"
sha256sum ${PROJECT}.gds

gzip -n --best ${PROJECT}.gds

echo "Done!"
exit 0
