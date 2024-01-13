ENTRY (_start)

MEMORY {
	BIOS_PGTBL : ORIGIN = 0xFFF80000, LENGTH = 64k
}

MEMORY {
	BIOS_BSS : ORIGIN = 0xFFF90000, LENGTH = 64k
}

MEMORY {
	BIOS_DATA : ORIGIN = 0xFFFA0000, LENGTH = 64k
}

MEMORY {
	BIOS_RODATA : ORIGIN = 0xFFFB0000, LENGTH = 64k
}

MEMORY {
	BIOS_CODE : ORIGIN = 0xFFFC0000, LENGTH = 252K
}

MEMORY {
	BIOS_RESET: ORIGIN = 0xFFFFF000, LENGTH=4k
}

PHDRS {
	bios_pgtbl PT_LOAD AT (0xFFF80000);
	bios_bss PT_LOAD AT (0xFFF90000);
	bios_data PT_LOAD AT (0xFFFA0000);
	bios_rodata PT_LOAD AT (0xFFFB0000);
	bios_code PT_LOAD AT (0xFFFC0000);
	bios_reset PT_LOAD AT (0xFFFFFFC0);
}

SECTIONS {
	.pgtbl: {
		. = 0xfff80000;
		*(.pgtbl);
	} >BIOS_PGTBL
	.bss: {
		. = 0xfff90000;
		_start_bss = .;
		_SDA_BASE_ = .;
		*(.bss);
		_end_bss = .;
	} >BIOS_BSS
	.data: {
		. = 0xfffa0000;
		_start_data = .;
		*(.data);
		_end_data = .;
	} >BIOS_DATA
	.rodata: {
		. = 0xfffb0000;
		_start_rodata = .;
		*(.rodata);
		_end_rodata = .;
	} >BIOS_RODATA
	.text: {
		. = 0xfffc0000;
		*(.text);
		_etext = .;
	} >BIOS_CODE
	.reset_vect: {
		_start_reset_vect = .;
		. = 0xffffffc0;
		*(.reset_vect);
		. = ALIGN(6);
		_end_reset_vect = .;
	} >BIOS_RESET
}
