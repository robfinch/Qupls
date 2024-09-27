# Welcome to Qupls (Q+)

## Overview
Qupls is an implementation of the Qupls instruction set architecture. The ISA is for a 64-bit general purpose machine. The Qupls ISA supports SIMD style vector operations.

### Versions
Qupls is the 2024 version of the Thor processor which has evolved over the years. Different versions are completely incompatible with one another as the author has learned and gained more experience.
QuplsSeq is a scalar version of the core.

### History
Work started on Qupls in November of 2023. Many years of work have gone into prior CPUs.

### Recent Additions
Provision for capabilities instructions were added to the instruction set. The capabilities version of the core requires 128-bit registers as a 64-bit capability is part of the register. This increases the size of the core considerably and turns Qupls into a 128-bit machine.

### Features Superscalar Out-of-Order version (Qupls.sv)
* Fixed length instruction set.
* 64-bit instructions.
* 64-bit datapath / support for 128-bit floats (128-bit datapath for capabilities)
* 16 entry (or more) reorder entry buffer (ROB)
* 256 general purpose registers, unified integer and float register file
* Independent sign control for each register spec.
* Register renaming to remove dependencies.
* Dual operation instructions: Rt = Ra op Rb op Rc
* Standard suite of ALU operations, add, subtract, compare, multiply and divide.
* Pair shifting instructions. Arithmetic right shift with round.
* Bitfield operations.
* Conditional relative branch instructions with 19-bit displacements
* 4-way Out-of-order execution of instructions
* 1024 entry, three way TLB for virtual memory support, shared between instruction and data

### Features Scalar In-Order version (QuplsSeq.sv)
* Fixed length instruction set.
* 48-bit instructions.
* 64-bit datapath / support for 128-bit floats
* 32 general purpose registers, unified integer and float register file
* 24 vector registers
* Independent control of vector or scalar type for each register spec.
* Independent sign control for each register spec.
* Dual operation instructions: Rt = Ra op Rb op Rc
* Standard suite of ALU operations, add, subtract, compare, multiply and divide.
* Pair shifting instructions. Arithmetic right shift with round.
* Bitfield operations.
* Conditional relative branch instructions with 19-bit displacements
* 128 entry, two way TLB for virtual memory support, shared between instruction and data

## Out-of-Order Version
### Status
The Qupls OoO machine is currently in development. The base machine has
been undergoing simulation runs. A long way to go yet. Some synthesis runs have been performed to get a general idea of the timing. The goal is 40 MHz operation.
The Qupls core is undergoing a major change from vector register support to just a massive number (256) of GP registers. The size of instructions is increasing to 64-bits to accomodate larger register specs.
### Historic Changes
The most recent major change to the ISA was a switch from 40 to 48 bits instructions. This was done to accomodate an increase in the size of a register specification while not losing any functionality.
The next most recent change was a reduction in the number of registers from 64 down to 32. This makes the hardware for the core considerably smaller, meaning more features can be added for the same footprint. There should not be a signficant effect on the performance caused by reducing the number of registers. For instance the ABI spec'd three global pointers for the 64-register version, but really only a single global pointer is needed.

### Register File
The register file contains 256 architectural registers, and is unified, supporting integer and floating-point operations using the same set of registers. 
There is a dedicated zero register, r0. There is no longer a register dedicated to refer to the stack canary or instruction pointer. Vector mask registers are repurposed as predicate register, and also part of the general purpose register file and the same set of instructions may be applied to them as to other registers. A register is also dedicated to the stack pointer. The stack pointer is banked depending on processor operating mode.
Five hidden registers are dedicated to micro-code use. They are only accessible from micro-code.
Registers are renamed to remove dependencies. There are 512 physical registers available.

### Vector Register File (this is repurposed now for 256 registers)
The vector register file may contain up to 32 vector registers. Each vector register is made up of eight 64-bit elements, or a total of 512-bits. Each element may contain multiple lanes of execution. The vector register file is currently implemented in the same block RAM as the general purpose register file and shares renaming resources with the general purpose registers. Each vector element is renamed, but individual lanes are not. The first eight vector registers v0 to v7 are aliased with the general-purpose registers. v0 and r0 to r7 are the same.
v1 and r8 to r15 are the same. And so on. That leaves 24 vector registers for general purpose use. The demo version running on an XC7A200T is only going to support about 16 vector registers.

### Instruction Length
The author has found that in an FPGA the decode of variable length instruction length was on the critical timing path, limiting the maximum clock frequency and performance. So, instructions are fixed length so that hardware decoders can be positioned at specific locations. Making the instruction length fixed 64-bits aids the hardware in determining the location of instructions and the update of the instruction pointer.

### Instruction alignment
Instructions are aligned on eight byte boundaries within a subroutine. Conditional branch displacements are in terms of instructions since the branch occurs within a subroutine where all instructions are eight bytes. Conditional branches have effectively a 20+ bit range. For software compatibility a critical 18 bits range was needed.
Subroutines may be aligned on any octabyte boundary, allowing position independent code placement. Unconditional branch and jump displacements are in terms of bytes to accomodate the location of subroutines.

### Position Independant Code
Code is relocatable at any octabyte boundary; however, within a subroutine or function the instructions should be contiguous, every six bytes, so that conditional branches will work.

### Pipeline
Yikes!
There are roughly nine stages in the pipeline, fetch, extract (parse), decode, rename, queue, issue, execute and writeback. The first few stages (up to que) are in-order stages.
The first step for an instruction is instruction fetch. At instruction fetch four instructions are fetched from the instruction cache. The fetched instructions are right aligned as a block then extracted from the cache line. Two cache lines worth of instructions are fetched to allow the group to cross a cache-line boundary. That means 16 instructions are fetched, but only four are processed further.
If there is a hardware interrupt, a special interrupt instruction overrides the fetched instructions and the PC increment is disabled until the interrupt is recognized.
After instruction fetch and extract the instructions are decoded. Decoded architectural registers are then renamed to physical registers and register values are fetched. The instruction decodes are placed in the reorder buffer / queued.
Once instructions are queued in the ROB they may be scheduled for execution. The scheduler has a fixed sized window of instructions it examines to find executable instructions. The window is from the far end of the ROB, the head point, backwards towards recently queued instructions. Only the oldest instructions in the queue are looked at as they are more likely to be ready to execute.
The next stage is execution. Note that the execute stage waits until all the instruction arguments are valid before trying to execute the instruction. (This is checked by the scheduler). The predicate register must be valid.
Instruction arguments are made valid by the execution or writeback of prior instructions. Note that while the instruction may not be able to execute, decode and execute are *not* stalled. Other instructions are decoded and executed while waiting for an instruction missing arguments. This is the out-of-order feature of the processor. Execution of instructions can be multi-cycle as for loads, stores, multiplies and divides.
At the end of instruction execution the result is placed into the register file. There may be a maximum of four instruction being executed at the same time. An alu, an fpu a memory and one flow control. Support to execute up to seven instructions is partially coded (2 ALU, 2 FPU, 2 Mem, 1 FCU).
The last stage, writeback, reorders instructions into program order reading the oldest instructions from the ROB. The core may writeback or commit four instructions per clock cycle. Exceptions and several other oddball instructions like CSR updates are also processed at the commit stage.

### Branch Prediction
There are two branch predictors, A BTB, branch-target-buffer predictor used early in the pipeline, and a gselect predictor used later. The BTB has 1024 entries. The gselect predictor is a (2,2) correlating predictor with a 512 entry history table. Even if the branch is correctly predicted a number of instructions may end up being stomped on the ROB. Currently branch prediction is disabled while work is being done on other aspects of the core.

### Interrupts and Exceptions
Interrupts and exceptions are precise. There is a separate exception vector table for each operating mode of the CPU. The exception vector table address is programmable and may contain a maximum of 256 vectors. At reset the vector table is placed high in memory.
An interrupt will cause the stack pointer to automatically switch to one dedicated for the operating mode (4 operating modes). There are seven interrupt levels supported.

## Instruction Set

### Sign Control
Each instruction operand has a sign-control bit associated with it. The sign of the operand may be negated or complemented when this bit is set. This is a simple enhancement of the instruction set which allows many more instructions without adding opcodes. For instance, a NAND operation is just and AND operation with the target register complement bit set.

### Dual Operation Instructions
Many register-register operate instructions support dual operations on the registers. They are of the form: Rt = (Ra op Rb) op Rc. For instance, the AND_OR instruction performs an AND operation followed by an OR operation. The compiler treats the processor as if it has only two source operands. Later in the optimization phase instructions that can be turned into dual-operations are dectected.

### Arithmetic Operations
The ISA supports many arithmetic operations including add, sub, mulitply and divide. Multi-bit shifts and rotates are supported. And a full set of logic operations and their complements are supported. Many ALU operations support three source registers and one destination register. Some operations like MULW, multiply widening, use two ALUs at the same time. Floating-point compares may be performed in an ALU.

### Floating-point Operations
The ISA supports floating-point add, subtract, multiply and divide instructions.
Several floating-point ops have been added to the core, including fused multiply-add, reciprocal and reciprocal square root estimates and sine and cosine functions. Four precisions are directly supported: half, single, double, and quad.
Quad precision operations are supported using register pairs and the quad precision extension modifier QFEXT. The modifier supplies the high order half of the quad precision values in the registers specified in the modifier. To perform a quad precision op the modifier is run through the ALU (not the FPU) to fetch the high half of the registers while the FPU fetches the low half. Then given both halves of registers the FPU can perform the quad precision operation. The result is written back to the register file using one write port from each of the ALU and FPU. Thus quad precision arithmetic may be performed.
The FPU can also perform many of the simpler ALU operations, this increases the number of instructions that can be handled in parallel.

### Large Constants
Use of large constants is supported with immediate mode instructions that can shift the immediate constant by multiples of 24-bits. ADD, AND, OR, and EOR all have shifted immediate mode instructions. This is sufficient to allow most calculations using large constants to be perfomed using a minimum of instructions. A 64-bit constant may be loaded into a register using only three instructions.

### Branches
Conditional branches are a fused compare-and-branch instruction. Values of two registers are compared, then a branch is made depending on the relationship between the two.
The branch displacement is over 20 bits, but it is in terms of instructions, effectively making it about 22 bits. Branches are currently being modified for 64-bit instructions and the branch range will likely increase.

### Loads and Stores
Load and store operations are queued in a memory (load/store) queue. Once the operation is queued execution of other instructions continues. The core currently allows only strict ordering of memory operations. Load and store instructions are queued in program order.
Stores are allowed to proceed only if it is known that there are no prior instructions that can cause a change of program flow.
Loads do not yet bypass stores. There is a component in the works that allows this but it does not work 100% yet.
There are bits in control register zero assigned for future use to indicate more relaxed memory models.

### Vector Instructions (deprecated)
The core will no longer directly support vector instructions. Vector register usage has been repurposed as GP registers. What vector instructions provided was code density. They are compact compared to performing operations using GP registers. However, the vector instructions required two extra pipeline stages for processing complicating the pipeline and impacting performance.
#### older text
The eventual goal is to support SIMD style vector instructions. The ISA is setup to support these. A large FPGA will be required to support the vector instructions with a full vector ALU. Vector operations mimic the scalar ones. There are no vector branches however. The current implementation implements vector instructions using micro-coded customized scalar instructions. <- This has been switched to expanding vector instructions in the extract stage, which improves performance of the vector operations. This allows the vector instruction set to execute on the scalar engine. Having more functional units, for instance, multiple ALUs will improve the vector performance.

## Memory Management
The core uses virtual addresses which are translated by a TLB. The MMU is internal to the core. The default MMU page size is 8kB. The page size may be set by MMU registers between 64B and 2MB. It was based on the recommendation that the page size be at least 16kB to improve memory efficiency and performance. The large page size also means that the address space of the test system can be mapped using only a single level of tables. Many small apps <8MB can be managed using just a single MMU page.

### TLB
The TLB is two-level. The first level is eight entries that are fully associative and can translate an address within a clock cycle. The second level is three-way associative with 1024 entries per way. Instructions and data both use the same TLB and it is always enabled. The TLB is automatically loaded with translations allowing access to the system ROM at reset. One of the first tasks of the BIOS is to setup access to I/O devices so that something as simple as a LED display may happen.
TLB updates due to a TLB miss are deferred until the instruction commits to mitigate Spectre attacks.
If the TLB miss processor runs into an invalid page table entry then a page table fault occurs.

### Table Walker
There is a hardware page table walker. The table walker is triggered by a TLB miss and walks the page tables to find a translation.

### Instruction Cache
The instruction cache is a four-way set associative cache, 32kB in size with a 512-bit line size. There is only a single level of cache. (The system also caches values from DRAM and acts a bit like an L2 cache). The cache is divided into even and odd lines which are both fetched when the PC changes. Using even / odd lines allows instructions to span cache lines.

### Data Cache
The data cache is 64kB in size. The ISA and core implementation supports unaligned data accesses. Unaligned access support is a configurable option as it increases the core size.

# Software
Qupls will use vasm and vlink to assemble and link programs. vlink is used 'out of the box'. A Qupls backend is being written for vasm. The Arpl compiler may be used for high-level work and compiles to vasm compatible source code.

# Core Size
The minimum core size including only basic integer instructions the core is about 100,000 LUTs or 160,000 LC's in size. The minimum size does not allow for much parallelism. Better performance may be had using a pipelined in-order processor which is much smaller.
A larger core including 2 ALUs and FPU allowing more parallelism is about 175k LUTs in size.
*The core size seems to be constantly increasing as updates occur.

# Performance
The toolset indicates the core should be able to reach 33 MHz operation. Under absolutely ideal conditions the core may execute four instructions per clock. All stages support processing at least four instructions per clock. Realistically the core will typically execute less than one instruction per clock.

# Putting the Core Together
There are many components to the CPU core. Some components are generic library components found elsewhere in Github repositories. All components germaine to Qupls begin with name prefix "Qupls" and are in the Qupls repository.

Qupls.sv is the top level for the CPU. Minimum of about 100k LUTs.
QuplsMpu.sv is the top level for the MPU which contains the CPU, timers, and interrupt controller.
