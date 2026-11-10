# writeback
Writeback stage related files contained here.
* Qupls4_frq_select.sv: selects from functional results queues to supply register file write ports.
As many queue results as are ready and write ports available are used.
* Qupls4_func_result_queue.sv: queues for results from functional units of the execute stage
