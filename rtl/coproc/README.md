# Stark_coproc.sv
## Overview
The StarkCPU co-processor is a much smaller 32-bit sequential implementation for the StarkCPU instruction set. It supports most of the integer instruction set.
* Floating-point is not supported.
* The divide instruction DIV/DIVA is not supported.
* Only 32-bit loads and stores are supported.
* Load / Store operations must be aligned.
* There is no loop counter.

The co-processor is about 1% of the size of the OoO core.

The co-processor is intended for debugging purposes. It has its own built-in ROM and scratchpad RAM.
* 0xC000 to 0xFFFF is the ROM area
* 0xF000 to 0xFFFF is the scratchpad RAM area.
* 0x0000 to 0xBFEF is an I/O area accessing the main CPU's components
* 0xBF00 to 0xBFFF is the serial port
## Bus Interface
The co-processor interfaces to external memory/IO as a bus master using a subset of the WISHBONE bus.
### WISHBONE datasheet:
|Description									 | Specification     |
|------------------------------|-------------------|
|General Description					 | co-processing CPU |
|Supported Cycles              | MASTER read/write |
|Data port Size                | 32 bits           |
|Data port Granularity         | 32 bits           |
|Data port Maximum Operand Size| 32 bits           |
|Data transfer ordering        | little endian     |
|Data transfer sequencing      | any               |
|Clock Frequency Constraints   | none              |
### Supported Signal List:
|Signal|WISHBONE Equiv.|                        |
|------|---------------|------------------------|
| rst  | rst_i         | bus reset,cpu reset    |
| clk  | clk_i         | bus clock              |
| cyc  | cyc_o         | indicates valid cycle  |
|  wr  | we_o          | write cycle is active  |
| adr  | adr_o         | 16-bit address bus     |
| din  | dat_i         | 32-bit data input      |
| dout | dat_o         | 32-bit data output     |