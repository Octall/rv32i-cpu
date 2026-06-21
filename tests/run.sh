#!/usr/bin/env bash
# Run compiled rv32ui hex tests on the core and report pass/fail.
# Usage:  bash tests/run.sh            # all built tests (skips fence_i)
#         bash tests/run.sh add sub
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/tests/build"
RUNNER="$OUT/runner.vvp"
OBJDUMP=riscv64-unknown-elf-objdump

# compile the runner with the core (exclude the board-only wrappers)
iverilog -g2012 -o "$RUNNER" \
    $(ls "$ROOT"/rtl/*.sv | grep -vE 'nexys4_top|clock_divider') \
    "$ROOT/tb/test_runner.sv"

names=("$@")
if [ ${#names[@]} -eq 0 ]; then
    names=()
    for f in "$OUT"/*.hex; do
        n=$(basename "$f" .hex)
        [ "$n" = "fence_i" ] && continue          # needs self-modifying code (Harvard can't)
        names+=("$n")
    done
fi

pass=0; fail=0
for name in "${names[@]}"; do
    th=$($OBJDUMP -t "$OUT/$name.elf" | awk '/ tohost$/{print $1}')
    [ -z "$th" ] && th=510
    res=$(vvp "$RUNNER" +HEX="$OUT/$name.hex" +TOHOST="$th" 2>/dev/null | grep -E "PASS|FAIL")
    printf '%-10s %s\n' "$name" "$res"
    case "$res" in *PASS*) pass=$((pass+1));; *) fail=$((fail+1));; esac
done
echo "------------------------------------"
echo "rv32ui: $pass passed, $fail failed"
