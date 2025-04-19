# register_file
This folder contains source code related to the register file.
# Primary components
* Stark_regfileRam.sv: the register file for one port. Contains 512, 72-bit entries with byte write enables. Eight bits are used for tags.
* Stark_regfile4wNr.sv: higher level register file containing multiple read/write ports and a live value table. Input values are bypassed to the output when the read/write regno matches. Output is also forced to zero for a read of register zero.
* Stark_read_port_select.sv: multiplexes 26 ports down to 16 ports to help reduce the amount of resources used by the register file. The selector has both fixed and rotating outputs. More docs in the .sv file.
* Stark_rat.sv: Register Alias Table, maps logical to physical registers. Also contains checkpoint logic for tracking register state for branches. The valid bit for the register file is also controlled here.
* Stark_reg_name_supplier2.sv: supplies newly mapped destination registers. Can supply up to four destination register names per clock. Uses a bitmap of allocated physical registers and interfaces to the checkpoint logic.
## Alternate components under development
* Stark_reg_renamer3.sv: an older version of a name supplier which uses an SRL fifo based approach. Does not work 100% correctly.
* Stark_reg_renamer4.sv: an older version of a name supplier which uses a fifo based approach. Does not work 100% correctly.
* Stark_reg_renamer_fifo.sv: support fifo for reg_renamer4.
* Stark_reg_renamer_srl.sv: support file for reg_renamer3.
* Stark_regfile6wNr.sv: an alternate register file with six write ports. Not use since the RAT only support four ports.
