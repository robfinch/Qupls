# Extract
The extract stage:
* aligns the instructions coming from the cache-line
* extracts four instructions
* maps the ISA instructions to raw micro-ops (these will be expanded in decode)
* sets up single step mode
* computes conditional branch and jumps and subroutine destinations, feeds the BTB
## Files:
* Qupls4_pipeline_ext.sv:	the extract stage pipeline
* Qupls4_ins_extract_mux.sv:	part of the mux pipeline stage, multiplexes micro-code and interrupts into the instruction stream

