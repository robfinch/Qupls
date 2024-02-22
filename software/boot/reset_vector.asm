; reset_vector.asm Qupls assembly language

	.section .pgtbl
_pgtbl:
	.8byte	0

	.section .reset_vect
	.org 0x160
_nmi_vect:
	jmp 0xFFFFFFFFFFFC0000
	nop
	.org 0x180
_reset_vect:
	jmp 0xFFFFFFFFFFFC0000
	nop
	.type	_reset_vect,@object
	.size	_reset_vect,16
