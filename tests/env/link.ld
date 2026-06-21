/* Place code at address 0 (the core's reset PC), data right after. */
OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS {
  . = 0x00000000;
  .text.init : { *(.text.init) }
  . = ALIGN(4);
  .text      : { *(.text) *(.text.*) }
  . = ALIGN(4);
  .rodata    : { *(.rodata) *(.rodata.*) }
  . = ALIGN(4);
  .data      : { *(.data) *(.data.*) *(.sdata) }
  . = ALIGN(4);
  .bss       : { *(.bss) *(.sbss) *(COMMON) }
  . = ALIGN(4);
  _end = .;
}
