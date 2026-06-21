/* Unified-image linker script for the single-cycle RV32I core.
 * Everything is linked at 0x0 and the SAME hex is loaded into BOTH Harvard
 * memories: instruction fetch hits the imem copy, loads/stores hit the dmem
 * copy. .bss and the stack live above the loaded image, inside dmem.
 * MMIO (UART / cycle counter / halt) lives at 0x1000_0000 and is referenced
 * directly from C via volatile pointers (see bench/port/mmio.h) -- it is NOT
 * part of this image. */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY { RAM : ORIGIN = 0x00000000, LENGTH = 64K }   /* 16384 words */

SECTIONS {
  /* ALIGN(4) on each section forces its START to a word boundary. This is the
   * reliable form -- a bare ". = ALIGN(4);" between region-bound sections is not
   * always honored, which previously let .bss start mid-word (0x86) sharing a
   * word with .rodata, so crt0's word-store bss-zeroing clobbered the last
   * rodata word. crt0 zeroes [__bss_start,__bss_end) with `sw`, so BOTH must be
   * word-aligned and must not overlap any loaded section's word. */
  .text.init : ALIGN(4) { *(.text.init) }                 > RAM
  .text      : ALIGN(4) { *(.text) *(.text.*) }           > RAM
  .rodata    : ALIGN(4) { *(.rodata) *(.rodata.*) *(.srodata*) } > RAM
  .data      : ALIGN(4) { *(.data) *(.data.*) *(.sdata*) } > RAM
  .bss (NOLOAD) : ALIGN(4) {
    __bss_start = .;
    *(.bss) *(.sbss*) *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > RAM
  _stack_top = ORIGIN(RAM) + LENGTH(RAM) - 16;            /* 0x0000FFF0 */
  /DISCARD/  : { *(.comment) *(.riscv.attributes) *(.eh_frame*) }
}
