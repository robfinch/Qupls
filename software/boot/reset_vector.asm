; reset_vector.asm Qupls assembly language

	.section .pgtbl
_pgtbl:
	.8byte	0

	.section .reset_vect

_reset_vect:
	; initial machine stack pointer
	.8byte	0xFFFFFFFFFFFAFFF0
	; initial program counter
	.8byte	0xFFFFFFFFFFFC0000
	.type	_reset_vect,@object
	.size	_reset_vect,16
