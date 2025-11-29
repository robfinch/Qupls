# pipeline
This folder contains files related to the in-order front end pipeline.
* Qupls4_pipeline_dec.sv:	the decode stage pipeline
* Qupls4_pipeline_fet.sv:	the fetch stage pipeline
* Qupls4_pipeline_ren.sv:	the rename stage pipeline
* Qupls4_pipeline_mux.sv:	the multiplex (extract) stage pipeline
* Qupls4_pipeline_que.sv:	holding pipeline register for most recently queued instruction group
* Qupls4_ins_extract_mux.sv:	part of the mux pipeline stage, multiplexes micro-code and interrupts into the instruction stream
