# Qupls4 Co-Processor

## Overview
The system co-processor (SCP) is capable of performing small tasks including MMU TLB miss handling.

## History
The co-processor project was started in February 2026.

## Features
* 16 general-purpose registers
* 15-bit instruction addresses
* 64-bit data path
* only basic operations
* custom accelerator instructions for TLB
* video scan position based branches
* about 25 instructions
* fast interrupt servicing
* 16-entry internal stack

## Programming Model
There are 15 general-purpose registers r1 to r15 plus r0 which is always zero.
There is an instruction pointer.

There is a 32kB high-speed local RAM / ROM for software support.
The instruction pointer only has enough bits to reference this memory.

All branches are absolute. The branch instruction directly specifies the destination address.

## Interrupt Servicing
Interrupts are serviced very quickly. The time to get to an ISR is only a few clock cycles.
ISR are used to handle TLB misses so they must be short and fast.
An internal 16-entry stack is used for interrupt servicing.
The stack can hold the first eight registers plus the instruction pointer in each entry.
On interrupt, the IP and registers r1 to r8 are automatically stored on the stack within a clock cycle or two.
The local RAM / ROM is moved out of low power mode (this requires two clock cycles).

## Anticipated Usage
A program will sit in a waiting loop waiting to service either the TLB miss or the video frame interrupt.

## Instruction Set
The instruction set is limited but is functional enough to perform a wide variety of tasks.
Instructions are 32-bit.
There are very few instructon formats.
* WAIT - may wait for interrupts or video scan position
* STORE - always a 64-bit value
* JUMP - unconditional jump
* Jcc - conditional branches, signed branches only, plus branch on scan position
* JSR - subroutine call, stores to internal stack, max depth <16
* RET - pops selected registers from stack
* ADD - addition, two registers and a constant, 64-bit constant possible
* AND - bitwise AND, 64-bit constant possible
* OR - bitwise OR
* XOR - bitwise exclusive OR
* SHL - shift left maximum shift of 31-bits
* SHR	- shift right maximum shift of 31-bits
* LOAD - always a 64-bit value

### Custom Instructions for TLB miss support.
These instruction enhance the performance of the miss routine by performing several operations within two clock cycles.
* CALC_INDEX - computes the table index part given the miss address, table level and page size
* CALC_ADR - computes a PTE address given page table address and index
* BUILD_VPN - puts together the VPN, ASID and COUNT fields for the upper 64-bits of a TLB entry
* BUILD_ENTRY_NO - puts together the way and entry number

### Flow Control Operations
The WAIT instruction waits for an interrupt to occur, or for a write cycle to a specific address.
There are currently two sources of interrupt, a TLB miss interrupt, and a video frame interrupt.
The WAIT instruction may also wait conditionally for a video scan position to be reached.
While waiting the SCP's local RAM/ROM is placed in low power mode.

There is a subroutine jump instruction, JSR, which places the return address on an internal 16-entry stack.
When subroutines are called, or for interrupts, the first eight registers are automatically stored on an internal stack.
This happens very quickly within a clock cycle or two.

There are a pair of conditional branches that may branch based on whether the scan position ahs been reached or not.
There is also a decrement-and-branch instruction.

### Memory Operations
Memory Operations are always 64-bit.
There is only one address mode, register indirect with displacement.
There is a STORE immediate instruction which may store a constant directly to a memory location.
This is useful for updating registers (audio / video) from a video frame handler.

### ALU Instructions
As above.
There is currently no subtract instruction, it must be synthesized.

# Performance
Current timing is for 150 MHz in a -2 device.
Average instructions per clock is about 0.4.
