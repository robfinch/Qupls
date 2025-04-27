# Welcome to StarkCPU (Qupls3)

## Overview
StarkCPU is an implementation of the StarkCPU instruction set architecture. The ISA is for a 32/64-bit general purpose machine.

### Versions
StarkCPU is the most recently worked on version evolved quickly from Qupls2 which the 2025 version of the Thor processor which has evolved over the years. Different versions are completely incompatible with one another as the author has learned and gained more experience.

### History
Work started on Qupls2 in February of 2025; then StarkCPU started in March. Work started on Qupls in November of 2023. Many years of work have gone into prior CPUs.

### Recent Additions
Many of the additions to earlier versions of Qupls have been removed to simplify the instruction set.

### Features Superscalar Out-of-Order version (StarkCPU.sv)
* Fixed length instruction set - 32-bits
* Large constants placed on the cache-line in-line following instructions.
* 32/64-bit datapath
* 16 entry (or more, currently 32) reorder entry buffer (ROB)
* Registers, independent integer and float register files
* 32 general purpose registers
* 32 floating-point registers
* 8 branch registers
* 8 condition registers
* 4 designated carry registers (any register may be used for carry)
* Register renaming to remove dependencies.
* Standard suite of ALU operations, add, subtract, compare, multiply and divide.
* Conditional relative branch instructions with 13-bit displacements
* Predicated logic with predicating branches, up to eight instructions may be skipped over
* 4-way Out-of-order execution of instructions
* 1024 entry, three way TLB for virtual memory support, shared between instruction and data
* 32kB four-way instruction cache
* 64kB four-way data cache

## Out-of-Order Version
### Status
* StarkCPU is primarily being designed with some code inherited from Qupls.
* The StarkCPU OoO machine is currently in development. A long way to go yet.

### Historic Changes
* StarkCPU evolved from Qupls2 and Qupls. The instruction formats are completely different.
* StarkCPU goes back to using a fixed length instruction, this time 32-bits.
* Some experimentation was done with placing constants at the end of a cache line.
* There should not be a signficant effect on the performance caused by reducing the number of registers.

### Register File
* The register file contains 96 architectural registers split into different groups. Both integer and floating-point operations are supported using separate registers. There are also eight branch registers, eight condition registers, and four carry registers.
* There is a dedicated zero register, r0. A register is dedicated to the stack pointer.
* A separate register bank is available for each operating mode. The first eight registers and the condition code registers are shared between modes. Floating-point is only available to the user / app mode.
* User mode: 96 regs, Supervisor: 40, Hypervisor: 40, and Secure: 48.
* Five hidden registers are dedicated to micro-code use.
* The register file is 16r4w (16 read ports and 4 write ports). This provides a good level of coverage for instructions. It may not always be possible to accomodate the current set of instructions in which case the latency increases as additional clock cycles are required. For instance, there may be up to 26 read ports required in the worst case, along with 17 write ports. The worst case is not being directly supported because of the hardware cost.
* The register file is organized with potentially five read ports for each instruction. There could be up to seven instructions requiring port access at the same time. Three read ports are for source operands A, B, and C. One port is for the target operand T which also needs to be readable. And there is a carry input port as well. Not all types of instruction require all these ports.
* Registers are renamed to remove dependencies. There are 512 physical registers available, or approximately 2.3 rename registers per register.

### Instruction Length
The author has found that in an FPGA the decode of variable length instruction length was on the critical timing path, limiting the maximum clock frequency and performance. The decode has been simplified.

### Instruction alignment
* Instructions are aligned on four byte boundaries within a subroutine. Conditional branch displacements are in terms of instructions since the branch occurs within a subroutine where all instructions are four bytes. Conditional branches have effectively a 13 bit range (this may be extended to 32-bits)
* Subroutines may be aligned on any four byte boundary, allowing position independent code placement. Unconditional branch and jump displacements are in terms of bytes to accomodate the location of subroutines.

### Position Independant Code
Code is relocatable at any four byte boundary; however, within a subroutine or function the instructions should be contiguous, so that conditional branches will work.

### Pipeline
Yikes!
![Pipeline Diagram](doc/StarkCPU_block_diagram.jpg?raw=true)
There are roughly ten stages in the pipeline, fetch, extract (parse), decode, rename, queue, issue, execute, deque and writeback. The first few stages (up to queue) are in-order stages.
#### Fetch / Extract Stages
* The first step for an instruction is instruction fetch. At instruction fetch two instruction cache lines are fetched to accomodate instructions spanning cache lines. That means up to 32 instructions are fetched, but only four are processed further. Four instructions are extracted from the cache lines. The fetched instructions are right aligned as a block.
* If there is a hardware interrupt, the interrupted instruction is tagged as interrupted by hardwware. This tag can be cleared later in the pipeline if interrupts were disabled for that instruction.
#### Decode Stage
* After instruction fetch and extract the instructions are decoded.
* Instructions are quickly translated into micro-ops and buffered. There may be as many as six micro-ops for an instruction. Most instructions require only one or two micro-ops.
* The ATOM instruction is processed and create masking for interrupts.
* Decode passed four micro-ops to the rename stage, once the micro-op buffer is exhausted, more instructions are requested from the extract stage.
#### Rename Stage
* Destination logical registers are assigned names from a name supplier component which can supply up to four names per clock cycle. Destination name mappings are stored in the RAT. Decoded architectural registers are renamed to physical registers and register values are fetched. The instruction decodes are placed in the reorder buffer / queued.
#### Queue Stage
* The decoded and renamed micro-ops are copied to the reorder buffer in this stage. 
#### Issue Stage
* Once micro-ops are queued in the ROB they may be scheduled for execution. The scheduler has a fixed sized window of instructions it examines to find executable instructions. The window is from the far end of the ROB, the head point, backwards towards recently queued instructions. Only the oldest micro-ops in the queue are looked at as they are more likely to be ready to execute.
#### Execute Stage
* The next stage is execution. Note that the execute stage waits until all the instruction arguments are valid before trying to execute the micro-op. (This is checked by the scheduler).
* Micro-op arguments are made valid by the execution or writeback of prior micro-ops. Note that while the instruction may not be able to execute, issue and execute are *not* stalled. Other instructions are issued and executed while waiting for a micro-op missing arguments. This is the out-of-order feature of the processor. Execution of micro-ops can be multi-cycle as for loads, stores, multiplies and divides.
* There can be two ALU, two FPU, two Memory and a branch micro-op executing at the same time (seven micro-ops). Each micro-op may generate only one result. For instance, a branch might store the link register and decrement the loop counter at the same time, but this is done as two separate micro-ops.
* Micro-op results are stored in queues. Queues are used as there may be up to seven results generated in a single clock cycle. Typically there would only be four or five results generated. But the CPU must have a means to handle the max.
#### Deque
* At the deque stage micro-op results that were queued are dequed in preparation for writeback. Deque proceeds at a maximum rate of four results per clock cycle (recall the register file has only four write ports). There is an 7:4 multiplexer which works in a rotating fashion.
#### Writeback
* At the end of micro-op execution the result is placed into the register file. There may be a maximum of four results at the same time.
* Results are also broadcast to reservation stations to make station values valid.
* The register file makes use of a live value table and four copies of the register file to provide four write ports in a CPU clock cycle.
#### Commit Stage
* Writeback reorders micro-ops into program order reading the oldest micro-ops from the ROB. The core may writeback or commit six micro-ops per clock cycle. Exceptions and several other oddball instructions like CSR updates are also processed at the commit stage.
* The commit stage will only commit micro-ops within the same checkpoint in any given clock cycle as the RAT is restricted to processing within only a single checkpoint at a time. Up to six micro-ops may be committed in a clock cycle. Four micro-ops of any type followed by up to two invalid micro-ops. 
#### Additional Notes
* Rename currently takes place as an asynchronous process operating on the re-order buffer.
* Interrupts are deferred to the start of a micro-op stream for any instruction. They are not allowed in the middle of the stream.
### Branch Prediction
* There are two branch predictors, A BTB, branch-target-buffer predictor used early in the pipeline, and a gselect predictor used later. The BTB has 1024 entries. The gselect predictor is a (2,2) correlating predictor with a 512 entry history table. Even if the branch is correctly predicted a number of instructions may end up being stomped on the ROB. Currently the gselect branch prediction is disabled while work is being done on other aspects of the core.

### Interrupts and Exceptions
* Interrupts and exceptions are precise. There is a separate exception vector table for each operating mode of the CPU. The exception vector table address is programmable and may contain a maximum of 16 vectors. At reset the vector table is placed high in memory.
* An interrupt will cause the entire register set to switch to one dedicated for the operating mode (4 operating modes).
* There are sixty-three interrupt levels supported.
* Interrupts are message signaled (QMSI). A message is sent by a device to an interrupt controller which then feeds the CPU core.
* Interrupt essentially occur at the first micro-op of a group as all micro-ops in the group are processed at the same time.

## Instruction Set

### Arithmetic Operations
* The ISA supports many arithmetic operations including add, sub, mulitply and divide. Multi-bit shifts and rotates are supported. And a full set of logic operations and their complements are supported. ALU operations only support two source registers and one destination register. Floating-point compares may be performed in an ALU.

### Floating-point Operations
* The ISA supports floating-point add, subtract, multiply and divide instructions.
* Several floating-point ops have been added to the core, including fused multiply-add, reciprocal and reciprocal square root estimates and sine and cosine functions.
* Quad precision operations are supported using register pairs and the quad precision extension modifier QFEXT. The modifier supplies the high order half of the quad precision values in the registers specified in the modifier. To perform a quad precision op the modifier is run through the ALU (not the FPU) to fetch the high half of the registers while the FPU fetches the low half. Then given both halves of registers the FPU can perform the quad precision operation. The result is written back to the register file using one write port from each of the ALU and FPU. Thus quad precision arithmetic may be performed.
* The FPU can also perform many of the simpler integer ALU operations, this increases the number of instructions that can be handled in parallel.
* FPU compares, absolute and negative values can be performed on the integer ALU.

### Large Constants
* Large constants are supported with the use of constants placed somewhere on the cache line after the instruction.
* The assembler places the large constants at the end of a cache line.
* A 32 or 64-bit constant may follow the instruction. This is sufficient to allow most calculations using large constants to be performed using a minimum of instructions.

### Branches
* Conditional branches are condition code based. A condition code register is set by the comparison of two registers or a register and a constant. Then a branch is made depending on the relationship between the two stored in the condition code register.
* The branch displacement is 11 bits, but it is in terms of instructions, effectively making it about 13 bits. Branch-to-register is also supported.
* Branches may optionally decrement a loop count register during the branch operation. This is useful for counted loops.

### Loads and Stores
* Load and store operations are queued in a memory (load/store) queue. Once the operation is queued execution of other instructions continues. The core currently allows only strict ordering of memory operations. Load and store instructions are queued in program order.
* Stores are allowed to proceed only if it is known that there are no prior instructions that can cause a change of program flow.
* Loads do not yet bypass stores. There is a component in the works that allows this but it does not work 100% yet.
* There are bits in control register zero assigned for future use to indicate more relaxed memory models.
* The operating mode used for a load or store may be overridden using the MPO (memory privilege override) instruction.

## Memory Management
* The MMU has both base and bound, and paged addresses.
* The core uses virtual addresses which are translated by a TLB. The MMU is internal to the core. The default MMU page size is 16kB. The page size may be set by MMU registers between 64B and 2MB. It was based on the recommendation that the page size be at least 16kB to improve memory efficiency and performance. The large page size also means that the address space of the test system can be mapped using only a single level of tables. Many small apps <8MB can be managed using just a single MMU page.
* Base and bound registers are available. The base register adjusts the miss output of the TLB by the base address. This causes the virtual address to be converted to a based or linear address. The paging system then sees the linear address. Base and bound registers are selected using the upper four bits of an address. They default to a base of zero, and a limiting bound of the maximum address, so that base / bound addressing essentially has no effect unless the base and bounds are changed.
* One benefit of base and bound addressing is that it may allow a page table to be shared by different processes.
* The lowest page level may be shortcutted allowing 1MB pages instead of 16kB.

### TLB
* The TLB is two-level. The first level is eight entries that are fully associative and can translate an address rapidly within a clock cycle. The second level is three-way associative with 1024 entries per way. Instructions and data both use the same TLB and it is always enabled. The TLB is automatically loaded with translations allowing access to the system ROM at reset. One of the first tasks of the BIOS is to setup access to I/O devices so that something as simple as a LED display may happen.
* TLB updates due to a TLB miss are deferred until the instruction commits to mitigate Spectre attacks.
* If the TLB miss processor runs into an invalid page table entry then a page table fault occurs.

### Table Walker
* There is a hardware page table walker. The table walker is triggered by a TLB miss and walks the page tables to find a translation.

### Instruction Cache
* The instruction cache is a four-way set associative cache, 32kB in size with a 512-bit line size. There is only a single level of cache. (The system also caches values from DRAM and acts a bit like an L2 cache). The cache is divided into even and odd lines which are both fetched when the PC changes. Using even / odd lines allows instructions to span cache lines.

### Data Cache
* The data cache is 64kB in size. The ISA and core implementation supports unaligned data accesses. Unaligned access support is a configurable option as it increases the core size. The core inherently supports unaligned access as long as the access will fit on a cache line. If the access does not fit, multiple accesses to the data cache are required.
* There is no guarentee of atomicity if the memory request spans a cache line.

# Software
* StarkCPU will use vasm and vlink to assemble and link programs. vlink is used 'out of the box'. A StarkCPU backend is being written for vasm. The Arpl compiler (supports 'C' code) may be used for high-level work and compiles to vasm compatible source code.

# Core Size
* The minimum core size including only basic integer instructions the core is estimated to be about 100,000 LUTs or 160,000 LCs in size. The minimum size does not allow for much parallelism. Better performance may be had using a pipelined in-order processor which is much smaller.
* A larger core including 2 ALUs and FPU allowing more parallelism is about 130k LUTs (208 LCs) in size.
* *The core size seems to be constantly increasing as updates occur*.

# Performance
* The toolset indicates the core should be able to reach 40 MHz operation (in a -2 device). Under absolutely ideal conditions the core may execute four micro-ops (instructions) per clock. All stages support processing at least four instructions per clock. Realistically the core will typically execute less than one instruction per clock.

# Putting the Core Together
* There are many components to the CPU core. Some components are generic library components found elsewhere in Github repositories. All components germaine to StarkCPU begin with name prefix "Stark" and are in the Qupls repository under the cpu_v3 folder.
* The cache code is located in the cache repository.

* StarkCPU.sv is the top level for the CPU. Minimum of about 100k LUTs.
* StarkMPU.sv is the top level for the MPU which contains the CPU, timers, and interrupt controller.
