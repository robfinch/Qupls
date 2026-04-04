# execute
Eventually modules related to the execute part of the design will go here.
Modules include ALU, FPU, Crypto, graphics, and others.

The execute stage is organized into eight parallel pipes, each pipe handling a different subset of instructions.

|Pipe 0    |1         |2         |3         |4         |5         |6         |7         | 
|----------|----------|----------|----------|----------|----------|----------|----------|
|ALU       |ALU       |ALU       |ALU       |ALU       |ALU       |FMA       |FMA       |
|CSR       |CRYPTO    |IMUL      |IMUL      |IDIV      |ISQRT     |          |          |
|COUNTS    |BRANCH    |FRCPA     |GRAPHICS  |MEM       |MEM       |          |          |
|SHIFT     |CAPAB.    |N. NET    |QUEUES    |          |TRIG      |          |          |
|BITFIELD  |          |          |          |          |          |          |          |
