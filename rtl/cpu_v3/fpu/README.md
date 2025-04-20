# fpu
This folder contains files for components related to the FPUs.
* Stark_fpu_station.sv: is a reservation station for ALUs
* Stark_fpu64.sv: is the main FPU component containing the arithmetic and some ALU operations for a 64-bit datapath.
* Stark_fpu128.sv: is the main FPU component containing the arithmetic and some ALU operations for a 128-bit datapath.
* Stark_meta_fpu.sv: is a top level FPU supporting multiple precisions.
* Stark_seqFPU2c.sv: is an FPU component implementing floating-point in a non-standard, two's complement format
