# register_file
This folder contains source code related to the register file.
# Primary components
* Qupls4_regfile_ram.sv: the register file for one port. Contains 512, 72-bit entries with byte write enables. Eight bits are used for tags.
* Qupls4_regfile4wNr.sv: higher level register file containing multiple read/write ports and a live value table. Input values are bypassed to the output when the read/write regno matches.
* Qupls4_read_port_select.sv: multiplexes 26 ports down to 12 ports to help reduce the amount of resources used by the register file. The selector has rotating outputs. More docs in the .sv file.
* Qupls4_rat.sv: Register Alias Table, maps logical to physical registers. Also contains checkpoint logic for tracking register state for branches. The valid bit for the register file is also controlled here.
* Qupls4_reg_name_supplier4.sv: supplies newly mapped destination registers. Can supply up to four destination register names per clock. Uses a bitmap of allocated physical registers and interfaces to the checkpoint logic.
## Alternate components under development
* Qupls4_reg_renamer3.sv: an older version of a name supplier which uses an SRL fifo based approach. Does not work 100% correctly.
* Qupls4_reg_renamer4.sv: an older version of a name supplier which uses a fifo based approach. Does not work 100% correctly.
* Qupls4_reg_renamer_fifo.sv: support fifo for reg_renamer4.
* Qupls4_reg_renamer_srl.sv: support file for reg_renamer3.
* Qupls4_regfile6wNr.sv: an alternate register file with six write ports. Not use since the RAT only support four ports.
