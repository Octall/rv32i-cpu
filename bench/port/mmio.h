/* mmio.h -- memory-mapped device handles for the RV32I SoC.
 * Matches the decode in cpu_top (is_mmio = addr[28], base 0x1000_0000) and
 * docs/uart-implementation-guide.md / docs/coremark-benchmark-plan.md. */
#ifndef MMIO_H
#define MMIO_H

#define UART_DATA (*(volatile unsigned int *)0x10000000u)  /* W: byte to send */
#define UART_STAT (*(volatile unsigned int *)0x10000004u)  /* R: bit0 = tx_busy */
#define CYCLES    (*(volatile unsigned int *)0x10000008u)  /* R: free-running cycles */
#define HALT_REG  (*(volatile unsigned int *)0x1000000Cu)  /* W: any store -> halt */

/* Block until the UART can accept a byte, then send it. */
static inline void uart_putc(char c) {
    while (UART_STAT & 1u) { }
    UART_DATA = (unsigned char)c;
}

static inline void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

/* Snapshot of the free-running cycle counter (the program's time source). */
static inline unsigned cycles(void) { return CYCLES; }

#endif /* MMIO_H */
