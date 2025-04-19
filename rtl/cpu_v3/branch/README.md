# branch
This folder contains components related to branch or flow control logic.
* gselectPredictor.sv: is a (2,2) correlating branch predictor with a 512-entry history table.
* Stark_branch_eval.sv: is a component that evaluates branch conditions and outputs a take-branch or do not take-branch status
* Stark_branchmiss_flag.sv: component that sets a pipeline flag based on the branch type and whether there was a branch miss.
* Stark_branchmiss_pc.sv: component that determines what the destination PC is for a branch miss.
* Stark_btb.sv: branch target buffer component with 1024 entries. Used in the fetch stage to determine the next PC.
