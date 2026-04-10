# execute
Eventually modules related to the execute part of the design will go here.
Modules include ALU, FPU, Crypto, graphics, and others.

The execute stage is organized into six parallel pipes, each pipe handling a different subset of instructions.
Pairs of pipelines can handle identical sets of instructions.

|Pipe 0/1  |2/3       |4/5       | 
|----------|----------|----------|
|ALU       |ALU       |ALU       |
|CSR       |IMUL      |IDIV      |
|BRANCH    |FMA       |ISQRT     |
|COUNTS    |FRCPA     |MEM       |
|SHIFT     |GRAPHICS  |FMA       |
|BITFIELD  |QUEUES    |TRIG      |
|CRYPTO    |N. Net    |          |
|CAPAB     |          |          |
|----------|----------|----------|
| Lat. 1   |    5     | 2 to 70  |
