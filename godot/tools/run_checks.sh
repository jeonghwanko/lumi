#!/usr/bin/env bash
set -euo pipefail
project=$(cd "$(dirname "$0")/.." && pwd)
godot_bin=${GODOT_BIN:-godot}
run_root=$(mktemp -d "${TMPDIR:-/tmp}/lumi-ui-checks.XXXXXX")
export XDG_DATA_HOME="$run_root/data" XDG_CACHE_HOME="$run_root/cache" XDG_CONFIG_HOME="$run_root/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$project/test-results"
export LUMI_UI_TEST=1
printf 'Isolated test state: %s\n' "$run_root"
"$godot_bin" --version
"$godot_bin" --headless --path "$project" --editor --import --quit >"$project/test-results/import.log" 2>&1
if grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script' "$project/test-results/import.log"; then
  cat "$project/test-results/import.log"; exit 1
fi
for test in cafe puzzle session garden screens ui review feedback; do
  "$godot_bin" --headless --path "$project" --script "res://tests/test_${test}.gd" 2>&1 | tee "$project/test-results/${test}.log"
  if grep -Eq 'SCRIPT ERROR|^ERROR:|^WARNING:.*leaked|^FAIL|Segmentation fault' "$project/test-results/${test}.log"; then exit 1; fi
done
"$godot_bin" --headless --path "$project" --export-pack "Linux Development" "$project/test-results/cats-and-coffee.pck" >"$project/test-results/export-pack.log" 2>&1
if grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error|Cannot export|Export failed' "$project/test-results/export-pack.log"; then
  cat "$project/test-results/export-pack.log"; exit 1
fi
printf 'Native tests + resource pack passed. APK/IPA and visual/device tests are separate.\n'
