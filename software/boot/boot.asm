; boot.asm Qupls assembly language

	.bss
	.space	10

	.data
	.space	10
	.sdreg 60

;	.org	0xFFFFFFFFFFFD0000
	.text
;	.align	0
.extern	_bootrom

start:
; set global pointers
	lda gp,_start_data
	orm gp,_start_data
	lda gp1,_start_rodata
	orm gp1,_start_rodata
	lda gp,_start_bss
	orm gp,_start_bss
	bra _bootrom
	nop
	nop
	nop
	nop
;	padi
	.type	start,@function
	.size	start,$-_start

.include "serial.asm"
.include "bootrom.asm"

.extern _start_data
.extern _start_rodata
.extern _start_bss
