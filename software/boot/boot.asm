# boot.asm Qupls assembly language

	.bss
	.space	10

	.data
	.space	10
	.sdreg 60

#	.org	0xFFFFFFFFFFFD0000
	.text
#	.align	0
.extern	_bootrom

start:
	bra _bootrom
