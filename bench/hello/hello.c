#include "mmio.h"
static const char msg[] = "Hello from RV32I\n";  /* .rodata */
static int table[4] = { 1, 2, 3, 4 };            /* .data   */
static int sink;                                 /* .bss    */
int main(void) {
    uart_puts(msg);
    int acc = 0;
    for (int i = 0; i < 4; i++) acc += table[i] * (i + 1);  /* forces __mulsi3 */
    sink = acc;
    return sink;          /* returned via a0 -> stored to HALT by crt0 */
}
