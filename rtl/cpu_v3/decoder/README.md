# decoder
* This folder contains files for a lot of small components used to decode instructions. They are not all described here as they are all basically the same.
* The instruction register is converted from a densely packed format into a set of individual decodes for each instruction or group of instructions. Further decoded is done in the modules specific to the instruction.
* The idea behind the decoder is to gain performance by breaking a cascade of decodes required for further processing of instructions.
* For instance the ALU decodes many ALU instruction in the ALU component. If it had to decode from the IR it would add to the delay.
* Stark_decoder.sv: is the top level for the decoder modules. Unimplemented instructions and bad register use are detected here.

