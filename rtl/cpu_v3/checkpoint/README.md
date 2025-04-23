# checkpoint
This folder contains files related to checkpoint logic for branches
* Stark_checkpoint_allocator.sv: allocates a checkpoint when a branch is encountered. Uses a bitmap to track allocation. By default only a single checkpoint is allocated per instruction group. A maximum of 16 checkpoints may be configured.
* Stark_checkpoint_freer.sv: frees up a previously allocated checkpoint. The checkpoint is freed only if all branches in the instruction group have resolved. The re-order buffer is monitored.
* Stark_checkpointRam.sv: (part of the RAT) keeps track of which registers were available at a given checkpoint when the checkpoint was assigned.
* Stark_checkpoint_manager.sv: contains other checkpoint modules. Instanced in the mainline Stark.sv
