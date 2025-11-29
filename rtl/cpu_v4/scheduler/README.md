# scheduler
This folder contains files related to the instruction scheduler.
* Qupls4_mem_sched.sv:	the load/store instruction scheduler, schedules from the load/store queue (LSQ)
* Qupls4_instruction_dispatcher.sv: dispatches instructions to functional unit reservation stations.

Note that scheduling also takes place in the reservation stations.
