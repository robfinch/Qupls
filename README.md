# Welcome to Qupls (Q+)

## Overview
Qupls is an implementation of the Qupls instruction set architecture. The ISA is for a 64-bit general purpose machine. The Qupls ISA supports SIMD style vector operations.

### Versions
Qupls is the 2024 version of the Thor processor which has evolved over the years. Different versions are completely incompatible with one another as the author has learned and gained more experience.
Qupls.sv is the top level for the CPU.

### History
Work started on Qupls in November of 2023.

### Features Out-of-Order version
Variable length instruction set.
64-bit datapath
32 entry (or more) reorder entry buffer (ROB)
64 general purpose registers, unified integer and float register file
64 vector registers
4-way Out-of-order execution of instructions
Interruptible micro-code.
128 entry, two way TLB for virtual memory support

## Out-of-Order Version
### Status
The Qupls OoO machine is currently in development. The base machine has
been undergoing simulation runs. A long way to go yet. 

### Register File
The register file contains 64 registers and is unified, supporting integer and floating-point operations using the same set of registers. 
There is a dedicated zero register, r0. There is also a register dedicated to refer to the stack canary. Predicate registers are also part of the general purpose register file and the same set of instructions may be applied to them as to other registers. A register is also dedicated to the stack pointer, which is special in that it is banked for different operating modes.
Four hidden registers are dedicated to micro-code use. They are only accessible from micro-code.

### Instruction Length
The author has found that in an FPGA the decode of variable length instruction length was on the critical timing path, limiting the maximum clock frequency and performance. So, the instruction length decode is pipelined and takes three clock cycle. This was based on the decision to go with a variable length instruction set for Qupls. Qupls supports extended length constants using postfix instructions. Postfix instructions are associated with the previous instruction and are fetched at the same time as the previous instruction. Effectively they are treated as if they were part of the instruction, but, the program counter still increments by the instruction length so the postfix instructions end up being fetched and treated as NOPs. This is slightly better than using additional instructions to encode constants as the entire instruction word is used to hold a constant making it more memory efficient.
Most instructions are four bytes, 32-bits, with several exceptions. Branches are five bytes to accomodate a compare-and-branch in a single instruction. NOPs are single byte to allow for alignment. Instructions requiring only a single source register are three bytes long.

### Instruction alignment
Instructions may be aligned on any byte boundary. Branch displacements and other target addresses are precise to the byte. Code may be relocated to any byte boundary.

### Pipeline
Yikes!
There are roughly eight stages in the pipeline, fetch, length decode, rename, decode, queue, issue, execute and writeback.
The first step for an instruction is instruction fetch. At instruction fetch four instructions are fetched from the instruction cache. Any postfix instructions associated with the fetched instructions are also fetched. If there is a hardware interrupt, a special interrupt instruction overrides the fetched instructions and the PC increment is disabled until the interrupt is recognized.
After instruction fetch the instructions are decoded. Decoded architectural registers are renamed to physical registers and register values are fetched. The instruction decodes are placed in the reorder buffer / queued.
The next stage is execution. Note that the execute stage waits until all the instruction arguments are valid before trying to execute the instruction.
Instruction arguments are made valid by the execution or writeback of prior instructions. Note that while the instruction may not be able to execute, decode and execute are *not* stalled. Other instructions are decoded and executed while waiting for an instruction missing arguments. Execution of instructions can be multi-cycle as for loads, stores, multiplies and divides.
At the end of instruction execution the result is placed into the register file. There may be a maximum of four instruction being executed at the same time. An alu, an fpu a memory and one flow control.
The last stage, writeback, reorders instructions into program order reading the oldest instructions from the ROB. The core may writeback or commit four instructions per clock cycle.

### Branch Prediction
There are two branch predictors, A BTB, branch-target-buffer predictor used early in the pipeline, and a gselect predictor used later. The BTB has 1024 entries.

### Interrupts and Exceptions
Interrupts and exceptions are precise.

### Arithmetic Operations
The ISA supports many arithmetic operations including add, sub, mulitply and divide. Multi-bit shifts and rotates are supported. And a full set of logic operations and their complements are supported.

### Floating-point Operations
Several floating-point ops have been added to the core, including fused multiply-add, reciprocal and reciprocal square root estimates and sine and cosine functions.

### Branches
Conditional branches are a fused compare-and-branch instruction. Values of two registers are compared, then a branch is made depending on the relationship between the two.
Conditional branch to register is also supported to allow conditional branches to take place to a target farther away than can be supported by the displacement. Conditional branch to register also allow conditional subroutine returns to be performed. The branch displacement is seventeen bits, so the range is +/- 64kB from the branch instruction.

### Loads and Stores
Load and store operations are queued in a memory (load/store) queue. Once the operation is queued execution of other instructions continues. The core currently allows only strict ordering of memory operations. Load and store instructions are queued in program order.
Stores are allowed to proceed only if it is known that there are no prior instructions that can cause a change of program flow.
Loads do not yet bypass stores. There is a component in the works that allows this but it does not work 100% yet.
There are bits in control register zero assigned for future use to indicate more relaxed memory models.

### Vector Instructions
The eventual goal is to support SIMD style vector instructions. The ISA is setup to support these. A large FPGA will be required to support the vector instructions. Vector instructions are indicated using a postfix. The postfix indicates the mask register to use, and which registers are vector or scalar registers. It may also control whether masked elements are skipped over or zeroed out.

### Instruction Postfixes
The author has learned a new trick, the one of using instruction postfixes.
The ISA uses instruction postfixes to extend constant ranges. In the author's opinion this is one of the better ways to handle large constants because the extension can be applied to a wide range of instructions without needing to add a whole bunch of instructions for larger constants. It can also be done with a fixed length instruction set.
Postfix processing is simpler than using prefixes because the postfix values can be pulled from the cache line after the instruction. Postfixes encountered in the instruction stream are treated as NOP instructions.

## Memory Management
The core uses virtual addresses which are translated by a TLB. The MMU is internal to the core. The MMU page size is 64kB. This is quite large and was chosen to reduce the number of block RAMs required to implement a hashed page table. The large page size also means that the address space of the test system can be mapped using only a single level of tables.

### TLB
The TLB is two-way associative with 128 entries per way. Instructions and data both use the same TLB and it is always enabled. The TLB is automatically loaded One of the first tasks of the BIOS is to setup access to I/O devices so that something as simple as a LED display may happen.

### Table Walker
There is a hardware page table walker. The table walker is triggered by a TLB miss and walks the page tables to find a translation.

### Instruction Cache
The instruction cache is a four-way set associative cache, 32kB in size with a 512-bit line size. There is only a single level of cache. The cache is divided into even and odd lines which are both fetched when the PC changes. Using even / odd lines allows instructions to span cache lines. While instructions are fixed length, they may be associated with instruction postfixes which provide extended immediate values for instructions. The instruction plus postfixes will always fit into a 512-bit cache line.

### Data Cache
The data cache is 64kB in size.

# Software
Qupls will use vasm and vlink to assemble and link programs. vlink is used 'out of the box'. A Qupls backend is being written for vasm. The CC64 compiler may be used for high-level work and compiles to vasm compatible source code.

# Core Size
Including only basic integer instructions the core is about 100,000 LUTs or 160,000 LC's in size. *The core size seems to be constantly increasing as updates occur.

# Performance
The toolset indicates the core should be able to reach 33 MHz operation. Under absolutely ideal conditions the core may execute four instructions per clock. All stages support processing at least four instructions per clock. Realistically the core will typically execute less than one instruction per clock.
