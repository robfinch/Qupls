; boot.asm Qupls assembly language

	.bss
	.space	10

	.data
	.space	10
	.sdreg 29

;	.org	0xFFFFFFFFFFFD0000
	.text
;	.align	0
.extern	_bootrom

start:
; set global pointers
	ldi sp,0xFFFFFFFFFFFAFFF0
	orm sp,0xFFFFFFFFFFFAFFF0
	lda gp,_start_bss
	orm gp,_start_bss
	bra _bootrom
.rept 16
	nop
.endr
;	padi
	.type	start,@function
	.size	start,$-_start

.include "Fibonacci.asm"
.include "serial.asm"
.include "bootrom.asm"

.extern _start_data
.extern _start_rodata
.extern _start_bss
