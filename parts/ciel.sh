# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# ---- ciel_enable: `ciel enable` that survives the loss of ciel's release index (included for the ciel PDKs only) ----
# usage: ciel_enable <family> <open_pdks commit> [more `ciel enable` options, e.g. -l <library>]
# ciel looks up what to download in three ways, tried in this order:
#  1. the default data source https://fossi-foundation.github.io/ciel-releases. Since 2026-11 it answers 301 to
#     www-archive.fossi-foundation.org, a name that has no DNS record ("Name or service not known").
#  2. the GitHub API (api.github.com). The cloud agent proxy answers 403 there: GitHub access is limited to the
#     session's own repositories.
#  3. the tarballs themselves, github.com/fossi-foundation/ciel-releases/releases/download/<family>-<commit>/<name>.tar.zst,
#     which the proxy does serve (github.com and release-assets.githubusercontent.com). ciel needs a list of them, and the
#     only list is behind 1 and 2, so this function probes the candidate names below with a 1-byte range request, writes
#     the manifests of ciel's "static-web" data source for those that exist, serves them on 127.0.0.1 and runs ciel on it.
# A library that is not in the candidate list is not installed in case 3: add its name to CIEL_CANDIDATES_<family>.
CIEL_CANDIDATES_gf180mcu="common gf180mcu_fd_pr gf180mcu_fd_io gf180mcu_fd_ip_sram gf180mcu_fd_sc_mcu7t5v0
  gf180mcu_fd_sc_mcu9t5v0 gf180mcu_ocd_io gf180mcu_ocd_alpha_large gf180mcu_ocd_alpha_small gf180mcu_ocd_ip_sram
  gf180mcu_as_sc_mcu7t3v3 gf180mcu_osu_sc_gp9t3v3 gf180mcu_osu_sc_gp12t3v3"
CIEL_CANDIDATES_sky130="common sky130_fd_io sky130_fd_pr sky130_fd_sc_hd sky130_fd_sc_hdll sky130_fd_sc_hs sky130_fd_sc_hvl
  sky130_fd_sc_lp sky130_fd_sc_ls sky130_fd_sc_ms sky130_fd_sp_sram sky130_ml_xx_hd sky130_sram_macros sky130_ef_io
  sky130_ef_sc_hd sky130_osu_sc_t12 sky130_osu_sc_t15 sky130_osu_sc_t18"

ciel_enable() {
  local fam=$1 commit=$2; shift 2
  local cand=CIEL_CANDIDATES_$fam
  ciel enable --pdk-root $F/pdks --pdk-family $fam "$@" $commit && return 0
  echo "PDK_RETRY via GitHub API (fossi-foundation.github.io refused?)"
  ciel enable --data-source github-releases:fossi-foundation/ciel-releases \
    --pdk-root $F/pdks --pdk-family $fam "$@" $commit && return 0
  echo "PDK_RETRY via direct release downloads (local manifest)"
  local W=/tmp/ciel-web base=https://github.com/fossi-foundation/ciel-releases/releases/download/$fam-$commit n found="" rc
  mkdir -p $W/$fam/$commit
  for n in ${!cand}; do
    [ "$(curl -sS -m 30 -L -r 0-0 -o /dev/null -w '%{http_code}' $base/$n.tar.zst 2>/dev/null)" = 206 ] \
      && found="$found $n" || echo "ciel_enable: no asset $n.tar.zst"
  done
  [ -n "$found" ] || { echo "ciel_enable: no asset found at $base"; return 1; }
  python3 - $W/$fam $commit $base $found <<'PY'
import json, sys
d, commit, base, libs = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
fam = d.rstrip("/").rsplit("/", 1)[1]
json.dump({"pdk": fam, "versions": [{"version": commit, "date": "2026-01-01T00:00:00Z"}]}, open(d + "/manifest.json", "w"))
json.dump({"assets": [{"content": l, "filename": l + ".tar.zst", "url": f"{base}/{l}.tar.zst"} for l in libs]},
          open(f"{d}/{commit}/manifest.json", "w"))
PY
  python3 -m http.server 8099 --bind 127.0.0.1 --directory $W > /dev/null 2>&1 &
  local srv=$!; sleep 1
  ciel enable --data-source static-web:http://127.0.0.1:8099 --pdk-root $F/pdks --pdk-family $fam "$@" $commit; rc=$?
  kill $srv 2>/dev/null; rm -rf $W
  return $rc
}
