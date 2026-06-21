#!/usr/bin/env bash
# Compile the rv32ui (RV32 user integer) tests to $readmemh hex images.
# Usage:  bash tests/build.sh            # all rv32ui tests
#         bash tests/build.sh add sub    # just these
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/riscv-tests/isa/rv32ui"
ENV="$ROOT/tests/env"
MAC="$ROOT/riscv-tests/isa/macros/scalar"
OUT="$ROOT/tests/build"
GCC=riscv64-unknown-elf-gcc
OBJCOPY=riscv64-unknown-elf-objcopy
mkdir -p "$OUT"

names=("$@")
if [ ${#names[@]} -eq 0 ]; then
    names=()
    for f in "$SRC"/*.S; do names+=("$(basename "$f" .S)"); done
fi

for name in "${names[@]}"; do
    $GCC -march=rv32i_zicsr_zifencei -mabi=ilp32 -nostdlib -nostartfiles \
         -I"$ENV" -I"$MAC" -T"$ENV/link.ld" \
         "$SRC/$name.S" -o "$OUT/$name.elf"
    $OBJCOPY -O binary "$OUT/$name.elf" "$OUT/$name.bin"
    python3 "$ROOT/tests/bin2hex.py" "$OUT/$name.bin" "$OUT/$name.hex"
    echo "built $name.hex"
done
