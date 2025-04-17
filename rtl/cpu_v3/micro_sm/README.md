# micro_sm
This folder contains source code for the micro state machine. It is similar to micro-code but not quite.
The micro_machine is a giant state machine used to implement macro instructions. The Stark_mcat.sv file contains a mapping of instructions to micro_machine states. It is a hard-coded table.
Instructions implemented include:
* enter
* exit
* push
* pop
* reset
* fdiv
* frsqrte	(float reciprocal square root estimate)
* fres (float reciprocal estimate)
The micro machine currently contains a lot of dead code. It is being ported from Qupls and the code needs to be removed.