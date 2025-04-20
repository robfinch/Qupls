# pipeline
This folder contains files related to the in-order front end pipeline.
* Stark_pipeline_dec.sv:	the decode stage pipeline
* Stark_pipeline_fet.sv:	the fetch stage pipeline
* Stark_pipeline_ren.sv:	the rename stage pipeline
* Stark_pipeline_mux.sv:	the multiplex (extract) stage pipeline
* Stark_pipeline_que.sv:	holding pipeline register for most recently queued instruction group
* Stark_ins_extract_mux.sv:	part of the mux pipeline stage, multiplexes micro-code and interrupts into the instruction stream
