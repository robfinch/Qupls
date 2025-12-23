# scheduler
This folder contains files related to the instruction scheduler.
* Qupls4_mem_sched.sv:	the load/store instruction scheduler, schedules from the load/store queue (LSQ)
* Qupls4_instruction_dispatcher.sv: dispatches instructions to functional unit reservation stations. Uses an out-of-order approach
* Qupls4_pipeline_dsp.sv: as above, but in-order stage
* Qupls4_validate_operand.sv: copies operands from the bus to reservation stations.
* Qupls4_validate_operand_pair.sv: like validate_operand, but copies even,odd pairs of operands.
* Qupls4_reservation_station.sv: get operands, and issue to execution units when ready.
* Qupls4_pair_reservation_station.sv: like get reservation_stations but for operand pairs.
* Qupls4_wp_history_tap.sv: (optional) snoops the register file write ports for values to load into the reservation stations.