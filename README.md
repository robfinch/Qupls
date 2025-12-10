# Welcome to Qupls4 (Q+)

## Overview
Qupls is an implementation of the Qupls instruction set architecture. The ISA is for a 64-bit general purpose machine. The Qupls ISA supports SIMD and vector operations.

### Versions
Qupls4 is the most recently worked on version. Qupls4 is the 2025 version of the Thor processor which has evolved over the years. Different versions are completely incompatible with one another as the author has learned and gained more experience.

### History
Qupls4 is the most recently worked on version beginning in November 2025. Work started on Qupls2 in February of 2025; then Qupls3 started in March. Work started on Qupls in November of 2023. Many years of work have gone into prior CPUs.

### Recent Additions
Provision for capabilities instructions were added to the instruction set. The capabilities version of the core requires 128-bit registers as a 64-bit capability is part of the register. This increases the size of the core considerably and turns Qupls into a 128-bit machine.

### Features Superscalar Out-of-Order version (Qupls4.sv)
* Fixed 48-bit length instruction set.
* 64-bit datapath / support for 128-bit floats (128-bit datapath for capabilities)
* 16 entry (or more) reorder entry buffer (ROB)
* 32 general purpose registers, unified integer and float register file
* 32 vector registers
* Independent sign control for each register spec. for many instructions.
* Constants may be substituted for registers, located in constant zones.
* Register renaming to remove dependencies.
* Dual operation instructions: Rt = Ra op Rb op Rc
* Standard suite of ALU operations, add, subtract, compare, multiply and divide.
* Arithmetic right shift with round.
* Bitfield operations.
* Conditional relative branch instructions with 21-bit displacements
* Vector operations.
* 4-way Out-of-order execution of instructions
* 1024 entry, three way TLB for virtual memory support, shared between instruction and data
* Message signaled interrupt handling.

## Out-of-Order Version
### Status
Qupls4 is primarily begin designed with some code inherited from Qupls2 / Stark and other projects.
The Qupls4 OoO machine is currently in development. A long way to go yet. Some synthesis runs have been performed to get a general idea of the size and timing. The goal is 40 MHz operation.
Qupls4 will have 32 GPRs instead of 64.
### Historic Changes
The most recent major change to the ISA was a switch back to fixed length instructions.
r0 is now a general-purpose register except when used as a base or index register for an address calculation in which case the value zero is used.
There should not be a signficant effect on the performance caused by reducing the number of registers.
Micro-code has been removed.

### Register File
The register file is 12r4w (12 read ports and 4 write ports). Previously the register file was 16r4w but the extra four ports are not needed most of the time.
There are now queues for writing and demultiplexing of read ports for reading.

#### Scalar Register File
The register file contains 32 architectural registers, and is unified, supporting integer and floating-point operations using the same set of registers. 
All 32 registers may be assigned by the compiler without restriction excepting for r0 as noted above.
There is only a suggested usage of r30 for the stack pointer. Any register may be used.
There is no longer a register dedicated to refer to the stack canary or instruction pointer.

#### Vector Register File
There are 32 vector 256-bit wide (4x64-bit chunks) registers and is unified, supporting integer and floating-point operations using the same set of registers.
The vector registers require 128 logical registers which are then mapped onto the 512 physical registers.

#### Physical Register File
The physical register file contains 512x64-bit registers.
Architectural registers are renamed using the physical registers to remove dependencies.
There are approximaately 168 (32+128+8) architectural registers, giving about 3.0 physical registers for each architectural one.

### Instruction Length
The author has found that in an FPGA the decode of variable length instruction length was on the critical timing path, limiting the maximum clock frequency and performance. Hence the move back to a fixed instruction length.

### Instruction alignment
Instructions are aligned on wyde (16-bit) boundaries. Conditional branch displacements are in terms of wydes. Conditional branches have effectively a 21 bit range. For software compatibility a critical 18 bits range was needed.
Subroutines may be aligned on any wyde boundary, allowing position independent code placement. Unconditional branch and jump displacements are in terms of wydes to accomodate the location of subroutines.

### Position Independant Code
Code is relocatable at any wyde boundary; however, within a subroutine or function the instructions should be contiguous, a multiple of six bytes.

### Pipeline
Yikes!
There are roughly nine stages in the pipeline, fetch, extract (parse), decode, rename, queue, issue, execute and writeback. The first few stages (up to que) are in-order stages.
#### Fetch / Extract Stages
The first step for an instruction is instruction fetch.
At instruction fetch two instruction cache lines are fetched to accomodate instructions spanning cache lines.
That means up to 21 instructions are fetched, but only four are processed further.
Four instructions are extracted from the cache lines. The fetched instructions are right aligned as a block according to the instruction pointer value.
A portion of the cache line following the instruction is also associated with the instruction so that constants may be decoded.
If there is a hardware interrupt, it is flagged on the instruction where the interrupt occurred.
#### Decode Stage
After instruction fetch and extract the instructions are decoded. 
Constants are also decoded from constant zones following the instruction.
ISA instructions are translated into micro-ops at this stage. Most instructions are a direct 1:1 translation but some instructions require more micro-ops.
#### Rename Stage
Target logical registers are assigned names from a name supplier component which can supply up to four names per clock cycle. Target name mappings are stored in the RAT. Decoded architectural registers are renamed to physical registers and register values are fetched. The instruction (micro-op) decodes are placed in the reorder buffer / queued.
#### Queue Stage
The queue stage is a place holder for the most recent instructions that have been queued in the reorder buffer.
Instructions are queued from the rename stage. The queue state overlaps the contents of the ROB.
It is less expensive to process the instructions from the queue buffer rather than multiplexing from the ROB.
#### Issue Stage
Once instructions are queued in the ROB they may be scheduled for execution.
The instruction scheduler is now distributed amongst the reservation stations which become active when instructions with valid arguments are ready.
##### Dispatch
There is a separate instruction dispatcher which dispatches instructions to the reservation stations.
The dispatcher may dispatch up to six micro-op instructions per clock cycle.
Not every combination of instructions is allowed to dispatch in the same clock cycle.
#### Execute Stage
The next stage is execution. Note that the execute stage waits until all the instruction arguments are valid before trying to execute the instruction. (This is checked by the scheduler). The predicate register must be valid.
Instruction arguments are made valid by the execution or writeback of prior instructions.
Note that while the instruction may not be able to execute, issue and execute are *not* stalled.
Other instructions are issued and executed while waiting for an instruction missing arguments.
This is the out-of-order feature of the processor.
Execution of instructions can be multi-cycle as for loads, stores, multiplies and divides.
Many instructions may be in the process of being executed at the same time, for example 14.
#### Writeback / Commit Stage
At the end of instruction execution the result is placed into the register file.
There may be a lot of instructions being executed at the same time depending on the availability of functional units.
The results of instructions executed are fed to queues. Many queues may all be loaded during the same clock cycle.
Four results per clock cycle are selected from the queues to update the register file.
Writeback reorders instructions into program order reading the oldest instructions from the ROB.
The core may writeback or commit six instructions per clock cycle.
Exceptions and several other oddball instructions like CSR updates are also processed at the commit stage.
The commit stage will only commit instructions within the same checkpoint in any given clock cycle as the RAT is restricted to processing within only a single checkpoint at a time.
Up to six instructions may be committed in a clock cycle. Four instructions of any type followed by up to two invalid instructions. 
Note that interrupts are processed at the first micro-op of an instruction which may contain multiple micro-ops.
This ensures the previous instruction is complete before the interrupt is processed.
### Branch Prediction
There are two branch predictors, A BTB, branch-target-buffer predictor used early in the pipeline, and a gselect predictor used later.
The BTB has 1024 entries. The gselect predictor is a (2,2) correlating predictor with a 512 entry history table.
Even if the branch is correctly predicted a number of instructions may end up being stomped on the ROB.
Currently the gselect branch prediction is disabled while work is being done on other aspects of the core.

### Interrupts and Exceptions
Interrupts and exceptions are precise.
There is a separate exception vector table for each operating mode of the CPU.
The exception vector table address is programmable. At reset the vector table is placed high in memory.
There are sixty-three interrupt levels supported.
Interrupts are message signaled (QMSI).
A message is sent by a device to an interrupt controller which then feeds the CPU core.
The QMSI controller snoops the response bus for interrupt messages, which are signaled as an error condition.

## Instruction Set

### Overview
Most instructions apply for either scalar or vector operations.
There is a bit (V) in the instruction to select either a vector or scalar register.

### Sign Control
Each instruction operand may have a sign-control bit associated with it depending on the instruction.
The sign of the operand may be negated or complemented when this bit is set.
This is a simple enhancement of the instruction set which allows many more instructions without adding opcodes.
For instance, a NAND operation is just and AND operation with the target register complement bit set.

### Dual Operation Instructions
Many register-register operate instructions support dual operations on the registers.
They are of the form: Rt = (Ra op Rb) op Rc.
For instance, the AND_OR instruction performs an AND operation followed by an OR operation.
The compiler treats the processor as if it has only two source operands.
Later in the optimization phase instructions that can be turned into dual-operations are dectected.

### Arithmetic Operations
The ISA supports many arithmetic operations including add, sub, mulitply and divide.
Multi-bit shifts and rotates are supported.
And a full set of logic operations and their complements are supported.
Many ALU operations support three source registers and one destination register.
Some operations like MULW, multiply widening, use two ALUs at the same time.
Floating-point compares may be performed in an ALU.

### Floating-point Operations
The ISA supports floating-point add, subtract, multiply and divide instructions.
Several floating-point ops have been added to the core, including fused multiply-add, reciprocal and reciprocal square root estimates and sine and cosine functions.
Four precisions are directly supported: half, single, double, and quad.
Quad precision operations are supported using even/odd register pairs.
The even/odd pair is stored in the reservation station as a pair.
The FPU can also perform many of the simpler ALU operations, this increases the number of instructions that can be handled in parallel.

### Large Constants
Large constants are supported by embedding them on the cache line in constant zones following the instruction.
The offset of the constant in the zone is encoded in the register spec for the register overridden with a constant.
Constant zones are 40 bit areas that may be concatonated together to form a large zone of up to 240 bits.
There may be multiple constants of multiple sizes stored in the zone as one instruction may have up to three constants.
Any of the three source registers may be turned into a constant.

### Branches
Conditional branches are a fused compare-and-branch instruction. Values of two registers are compared, then a branch is made depending on the relationship between the two.
The branch displacement is 21 bits. Branch-to-register is also supported.

### Loads and Stores
Load and store operations are queued in a memory (load/store) queue.
Once the operation is queued execution of other instructions continues.
The core currently allows only strict ordering of memory operations.
Load and store instructions are queued in program order.
Stores are allowed to proceed only if it is known that there are no prior instructions that can cause a change of program flow.
Loads may bypass stores in some circumstances (the load and store must match exactly).
There are bits in control register zero assigned for future use to indicate more relaxed memory models.

### Unimplemented Instructions
There are a handful of vector instructions that are not implemented due to the implementation.
For instance, a vector slide instruction may slide the operand a maximum of 64-bits.
How many elements are slid depends on the element size.

## Memory Management
The core uses virtual addresses which are translated by a TLB.
The MMU is internal to the core.
The default MMU page size is 8kB.
The page size may be set by MMU registers between 64B and 2MB.
It was based on the recommendation that the page size be at least 16kB to improve memory efficiency and performance.
The large page size also means that the address space of the test system can be mapped using only a single level of tables.
Many small apps <8MB can be managed using just a single MMU page.
The lowest page level may be shortcutted allowing 8MB pages instead of 8kB.

### TLB
The TLB is two-level. The first level is eight entries that are fully associative and can translate an address within a clock cycle.
The second level is three-way associative with 1024 entries per way.
Instructions and data both use the same TLB and it is always enabled.
The TLB is automatically loaded with translations allowing access to the system ROM at reset.
One of the first tasks of the BIOS is to setup access to I/O devices so that something as simple as a LED display may happen.
TLB updates due to a TLB miss are deferred until the instruction commits to mitigate Spectre attacks.
If the TLB miss processor runs into an invalid page table entry then a page table fault occurs.

### Table Walker
There is a hardware page table walker.
The table walker is triggered by a TLB miss and walks the page tables to find a translation.

### Instruction Cache
The instruction cache is a four-way set associative cache, 32kB in size with a 512-bit line size.
There is only a single level of cache. (The system also caches values from DRAM and acts a bit like an L2 cache).
The cache is divided into even and odd lines which are both fetched when the PC changes.
Using even / odd lines allows instructions to span cache lines.

### Data Cache
The data cache is 64kB in size. The ISA and core implementation supports unaligned data accesses.
Unaligned access support is a configurable option as it increases the core size.
Accesses spanning a memory page boundary (8kb) take longer to process.

# Software
Qupls4 will use vasm and vlink to assemble and link programs. vlink is used 'out of the box'.
A Qupls4 backend is being written for vasm.
The Arpl compiler may be used for high-level work and compiles to vasm compatible source code.

# Core Size
The minimum core size including only basic integer instructions the core is about 200,000 LUTs or 320,000 LCs in size.
The minimum size does not allow for much parallelism.
Better performance may be had using a pipelined in-order processor which is much smaller.
*The core size seems to be constantly increasing as updates occur.

# Performance
The toolset indicates the core should be able to reach 40 MHz operation (in a -2 device).
Under absolutely ideal conditions the core may execute four instructions or eight operations per clock.
All stages support processing at least four instructions per clock.
Realistically the core will typically execute less than one instruction per clock.

# Putting the Core Together
There are many components to the CPU core.
Some components are generic library components found elsewhere in Github repositories.
All components germaine to Qupls begin with name prefix "Qupls" and are in the Qupls repository.

Qupls4.sv is the top level for the CPU. Minimum of about 200k LUTs.
Qupls4_mpu.sv is the top level for the MPU which contains the CPU, timers, and interrupt controller.
