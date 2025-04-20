# miscellaneous
This folder contains files for miscellanout components that do not fit easily into other categories.
* Stark_backout_machine.sv: is a state machine used to perform a backout after a branch miss.
* Stark_commit_count.sv: calculates how many instructions can be committed.
* Stark_FuncResultQueue.sv: is a queue to store functional unit results until they can be written to the register file.
* Stark_queue_room.sv: calculates the amount of free space in the ROB available to queue instructions.
* Stark_stail.sv: resets the ROB tail pointers after a branch miss
* Stark_stomp.sv: calculates which instructions to stomp on

