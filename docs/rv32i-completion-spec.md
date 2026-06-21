# Spec: Complete RV32I and run riscv-tests

You have a working single-cycle core for a subset (R-type, I-ALU, `lw`, `sw`, `beq`).
To run the official **riscv-tests** you need (1) the *full* RV32I base ISA, and
(2) a small amount of test-harness plumbing. This is split into two stages.

Work the same way as before: implement each piece yourself; ask me for the
self-checking testbench when you start a module. Each `### contract` below is the
spec a testbench will hold you to.

---

## Stage 1 — complete the RV32I base ISA

### What's missing
| group | have | add |
|---|---|---|
| Loads  | `lw` | `lb`, `lh`, `lbu`, `lhu` (byte/half, signed & unsigned) |
| Stores | `sw` | `sb`, `sh` (byte/half) |
| Branch | `beq` | `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| Upper-imm | — | `lui`, `auipc` |
| Jumps | — | `jal`, `jalr` |
| Misc | — | `fence` (treat as NOP) |

`imm_gen` already produces all five formats (I/S/B/U/J), so **no change there** —
`jal` uses J, `jalr` uses I, `lui`/`auipc` use U.

### 1.1 ALU operand-A mux (new, in cpu_top)
Today ALU operand A is always `rs1_data`. Add a 2-bit select `alu_a_src`:
- `0` → `rs1_data` (normal)
- `1` → `pc`   (for `auipc`: `rd = pc + imm`)
- `2` → `32'd0` (for `lui`: `rd = 0 + imm = imm`)

Operand B keeps the existing `alu_src` (`rs2_data` vs `imm`).

### 1.2 `branch_unit` (new module)
Decides whether a conditional branch is taken, from `funct3`.

#### contract — `branch_unit(rs1_data, rs2_data, funct3) -> taken`
| funct3 | instr | taken when |
|---|---|---|
| 000 | beq  | `rs1 == rs2` |
| 001 | bne  | `rs1 != rs2` |
| 100 | blt  | `$signed(rs1) <  $signed(rs2)` |
| 101 | bge  | `$signed(rs1) >= $signed(rs2)` |
| 110 | bltu | `rs1 <  rs2` (unsigned) |
| 111 | bgeu | `rs1 >= rs2` (unsigned) |

### 1.3 Writeback source mux (expand `mem_to_reg` → `result_src[1:0]`)
There are now three things that can be written to `rd`:
- `0` → ALU result (R, I-ALU, **lui**, **auipc**)
- `1` → load data (after the load-extend unit, §1.5)
- `2` → `pc + 4` (link register for **jal**, **jalr**)

### 1.4 Next-PC / jump+branch target (in cpu_top)
The PC module already does `pc+4` when `pc_load==0`, so you only drive the override:
- **target mux** `pc_target`:
  - branches & `jal`: `pc + imm`
  - `jalr`: `(rs1_data + imm) & ~32'b1`  (the ALU already computes `rs1+imm`; just clear bit 0)
- **pc_load** = `jal | jalr | (branch & taken)`  (where `taken` is from `branch_unit`)

### 1.5 Load/store widths (the fiddly one)
RV32I accesses bytes/halves/words. Two new pieces around `data_memory`:

#### `store_align` — produce write data + byte-enable from `funct3`, `addr[1:0]`, `rs2_data`
- `sb` (000): write 1 byte at `addr[1:0]` → byte-enable has one bit set, data byte replicated to that lane.
- `sh` (001): write 2 bytes at `addr[1]` half → two enable bits.
- `sw` (010): all 4 enable bits.

#### `data_memory` — add a 4-bit byte write-enable
Replace the single `mem_write` write with per-byte lanes: for each of the 4 byte lanes, write it only if its enable bit is set (and `mem_write`). Read still returns the full 32-bit word.

#### `load_extend` — select & extend the read word by `funct3`, `addr[1:0]`
- `lb`  (000): byte at `addr[1:0]`, **sign**-extend
- `lh`  (001): half at `addr[1]`,   **sign**-extend
- `lw`  (010): full word
- `lbu` (100): byte, **zero**-extend
- `lhu` (101): half, **zero**-extend

### 1.6 `control_unit` — add the new opcodes
New opcodes: `lui`=0110111, `auipc`=0010111, `jal`=1101111, `jalr`=1100111,
`fence`=0001111. Branches/loads/stores now use `funct3` (passed to `branch_unit`,
`load_extend`, `store_align`). Full control table:

| instr | reg_write | alu_a_src | alu_src(B) | alu_op | result_src | mem_read | mem_write | branch | jal | jalr | imm_sel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| R      | 1 | rs1 | rs2 | funct | alu | 0 | 0 | 0 | 0 | 0 | – |
| I-ALU  | 1 | rs1 | imm | funct | alu | 0 | 0 | 0 | 0 | 0 | I |
| load   | 1 | rs1 | imm | ADD | mem  | 1 | 0 | 0 | 0 | 0 | I |
| store  | 0 | rs1 | imm | ADD | –    | 0 | 1 | 0 | 0 | 0 | S |
| branch | 0 | rs1 | rs2 | –   | –    | 0 | 0 | 1 | 0 | 0 | B |
| lui    | 1 | zero| imm | ADD | alu  | 0 | 0 | 0 | 0 | 0 | U |
| auipc  | 1 | pc  | imm | ADD | alu  | 0 | 0 | 0 | 0 | 0 | U |
| jal    | 1 | –   | –   | –   | pc+4 | 0 | 0 | 0 | 1 | 0 | J |
| jalr   | 1 | rs1 | imm | ADD | pc+4 | 0 | 0 | 0 | 0 | 1 | I |
| fence  | 0 | –   | –   | –   | –    | 0 | 0 | 0 | 0 | 0 | – |

Keep the default-first style: default everything to a safe NOP, then override per opcode.

### 1.7 Verify Stage 1
Before riscv-tests, prove each new piece with unit tests (ask me for them), then
extend the `cpu_top` program to exercise `lui`/`auipc`/`jal`/`jalr`/all branches/all
load-store widths. When that passes in sim, you have a complete RV32I core.

---

## Stage 2 — run the riscv-tests

### 2.1 Toolchain (you don't have these yet)
```bash
# RISC-V GCC (rv32). On Ubuntu, easiest is the prebuilt:
sudo apt install gcc-riscv64-unknown-elf      # use with -march=rv32i -mabi=ilp32
# the tests themselves:
git clone --recursive https://github.com/riscv-software-src/riscv-tests
```
We care about `riscv-tests/isa/rv32ui` (the RV32 user-level integer tests:
`add`, `sub`, `lw`, `beq`, `jal`, …). Each builds to an ELF.

### 2.2 Memory base
The stock `-p` tests link at `0x80000000`. Your memories start at `0x0`. Easiest fix:
build the tests with a **custom linker script** that places `.text` at `0x0` (and
data right after), so they fit your existing instruction/data memory. Bump your
`instr_memory`/`data_memory` `DEPTH` so the test image fits (a few K words).

### 2.3 The harness — two paths (recommended: the pragmatic one first)

**(A) Pragmatic custom environment (no privileged ISA needed) — do this first.**
The rv32ui *instruction* tests don't need CSRs themselves; only the default test
*environment* (`env/p`) uses ECALL + a trap handler to report results. Supply your
own minimal `riscv_test.h`/`crt` where `RVTEST_PASS`/`RVTEST_FAIL`:
- write a result code to a fixed **tohost address** (e.g. `0x1000`): `1` = pass,
  `(testnum<<1)|1` = fail at test N, then spin.
Your testbench (or the board) watches that address. This runs the real test bodies
with only the RV32I you built in Stage 1 — no CSRs, no traps.

**(B) Full bare-metal `env/p` (the "proper" way) — optional, later.**
To run the unmodified `-p` tests you must add a minimal **machine-mode** layer:
- CSR instructions: `csrrw/csrrs/csrrc` (+ `*i`), opcode `1110011`.
- CSRs: `mtvec`, `mepc`, `mcause`, `mstatus`, `mscratch`, `mhartid`.
- `ECALL`/`EBREAK` → trap to `mtvec`; `MRET` to return.
- The trap handler writes pass/fail to `tohost`.
This is a real chunk of work (≈ another control path + a CSR file). Worth doing as a
follow-on, but not required to validate your datapath.

### 2.4 Test runner (simulation)
A testbench that, for each `rv32ui-*.hex`:
1. `$readmemh` the test into instruction memory, reset, run.
2. Watch the tohost address; when it goes non-zero: `1` ⇒ PASS, else ⇒ FAIL (code/2
   = failing sub-test). Time out after N cycles ⇒ FAIL (hang).
Loop over all test hex files and print a pass/fail summary. (I can generate this
runner + the hex-conversion script when you reach it.)

---

## Recommended order
1. **Stage 1**, one module at a time, each with its testbench:
   `branch_unit` → ALU operand-A mux + `result_src` → next-PC/jump logic →
   `store_align`/`data_memory` byte-enables/`load_extend` → `control_unit` opcodes.
2. Extend the `cpu_top` program; confirm full-RV32I in sim (and re-flash the board for fun).
3. **Stage 2A**: toolchain + custom-env + the simulation test runner → green rv32ui.
4. **Stage 2B** (optional): CSR/trap layer for the unmodified `-p` tests.

Tell me which module you're starting and I'll hand you the stub + self-checking
testbench, exactly like the core.
```
