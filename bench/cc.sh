#!/usr/bin/env bash
# =============================================================================
# cc.sh -- compile C (and/or asm) source for the single-cycle RV32I core.
# =============================================================================
# Produces a $readmemh image (one little-endian 32-bit word per line) linked at
# 0x0. The SAME hex is loaded into BOTH Harvard memories (instr_memory and
# data_memory's INIT_FILE), so .text runs from imem while .rodata/.data/.bss
# and the stack live in dmem.
#
# Usage:
#   bench/cc.sh -o NAME  file1.c [file2.c ...]      [extra gcc flags]
#   bench/cc.sh          file1.c                    # NAME defaults to file1
#
# Examples:
#   bench/cc.sh -o hello bench/hello/hello.c
#   bench/cc.sh -o coremark bench/coremark/*.c bench/port/core_portme.c -O3
#
# Output:
#   build/<NAME>.elf   linked ELF (with symbols, for objdump/debug)
#   build/<NAME>.bin   flat binary
#   programs/<NAME>.hex  $readmemh image  <-- load this into the core
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="$ROOT/bench/port"

GCC=riscv64-unknown-elf-gcc
OBJCOPY=riscv64-unknown-elf-objcopy
OBJDUMP=riscv64-unknown-elf-objdump

ARCH="-march=rv32i -mabi=ilp32"          # base ISA only: no M/A/F/D
OPT="-O2"                                 # overridable via extra flags
MEM_WORDS=16384                           # instr/data memory depth (words)

# ---- parse args: -o NAME, then sources, then passthrough flags ----
NAME=""
SRCS=()
EXTRA=()
while [ $# -gt 0 ]; do
    case "$1" in
        -o) NAME="$2"; shift 2 ;;
        -o*) NAME="${1#-o}"; shift ;;
        *.c|*.S|*.s) SRCS+=("$1"); shift ;;
        *) EXTRA+=("$1"); shift ;;        # extra gcc flags (e.g. -O3 -DFOO=1)
    esac
done

if [ ${#SRCS[@]} -eq 0 ]; then
    echo "cc.sh: no source files given" >&2
    echo "usage: bench/cc.sh -o NAME file.c [more.c ...] [gcc flags]" >&2
    exit 2
fi
if [ -z "$NAME" ]; then
    NAME="$(basename "${SRCS[0]}")"; NAME="${NAME%.*}"
fi

mkdir -p "$ROOT/build" "$ROOT/programs"
ELF="$ROOT/build/$NAME.elf"
BIN="$ROOT/build/$NAME.bin"
HEX="$ROOT/programs/$NAME.hex"

# ---- compile + link (crt0 first so _start lands at 0x0) ----
# -nostdlib/-nostartfiles: bare metal, our own crt0 and linker script.
# -ffreestanding: no hosted-environment assumptions.
# -lgcc: software mul/div/shift helpers (RV32I has no hardware multiply).
"$GCC" $ARCH $OPT -nostdlib -nostartfiles -ffreestanding -ffunction-sections \
    -Wl,--gc-sections \
    -I"$PORT" -T"$PORT/link.ld" \
    "$PORT/crt0.S" "${SRCS[@]}" "${EXTRA[@]}" \
    -lgcc -o "$ELF"

# ---- ELF -> flat binary -> $readmemh hex ----
"$OBJCOPY" -O binary "$ELF" "$BIN"
python3 "$ROOT/tests/bin2hex.py" "$BIN" "$HEX"

# ---- report + size guard ----
WORDS=$(wc -l < "$HEX")
ENTRY=$("$OBJDUMP" -f "$ELF" | awk '/start address/{print $3}')
printf 'built %-18s  %5d words (%d bytes)  entry=%s\n' \
    "programs/$NAME.hex" "$WORDS" "$((WORDS * 4))" "$ENTRY"

if [ "$WORDS" -gt "$MEM_WORDS" ]; then
    echo "WARNING: image is $WORDS words but memory is $MEM_WORDS words --" \
         "raise DEPTH in rtl/instr_memory.sv and rtl/data_memory.sv" >&2
    exit 1
fi
if [ "$ENTRY" != "0x0" ] && [ "$ENTRY" != "0x00000000" ]; then
    echo "WARNING: entry point is $ENTRY, expected 0x0 (reset PC)" >&2
fi
