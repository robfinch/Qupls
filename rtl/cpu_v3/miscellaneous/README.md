# miscellaneous
This folder contains files for miscellanout components that do not fit easily into other categories.
* Stark_backout_machine.sv: is a state machine used to perform a backout after a branch miss.
* Stark_commit_count.sv: calculates how many instructions can be committed.
* Stark_func_result_queue.sv: is a queue to store functional unit results until they can be written to the register file.
* Stark_queue_room.sv: calculates the amount of free space in the ROB available to queue instructions.
* Stark_stail.sv: resets the ROB tail pointers after a branch miss
* Stark_stomp.sv: calculates which instructions to stomp on
* Stark_copydst.sv: sets the flag to copy the destination register value
* Stark_microop.sv: converts an ISA instruction into a series of micro-ops.
* Stark_map_dstreg_req.sv: searches the ROB for destination registers that have not been mapped to physical registers yet and requests a physical register for the destination. Has a window of 12-micro-ops.
