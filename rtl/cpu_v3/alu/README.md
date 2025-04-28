# alu
This folder contains files for components related to the ALUs.
* Stark_alu_station.sv: is a reservation station for ALUs
* Stark_alu.sv: is the main ALU component containing the arithmetic, logic, and shift calculators. There are two versions of the ALU controlled by a parameter. The first version includes everything. The second version is pared down and does not include less frequently used instructions.
* Stark_info.sv: is a file containing mostly read-only information about the CPU. It is here since it is read through the ALU. Present only in the first ALU.
* Stark_divider.sv: is a file containing the divider component. The divider is standard radix two divider. Present only in the first ALU.
* Stark_cmp.sv: is a file containing the comparator component. The comparator supports both integer and floating-point comparisons. It is also used in the FPU.
* Stark_meta_alu.sv: is a top level ALU supporting multiple precisions.
* Stark_validate_Rn.sv: marks arguments valid as they are read from the register file.