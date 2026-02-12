ENTRY (_start)

MEMORY {
	BIOS_CODE : ORIGIN = 0x0000, LENGTH = 26k
}

MEMORY {
	BIOS_BSS : ORIGIN = 0x7000, LENGTH = 2k
}

MEMORY {
	BIOS_DATA : ORIGIN = 0x7800, LENGTH = 2k
}

MEMORY {
	BIOS_RODATA : ORIGIN = 0x6800, LENGTH = 2K
}

PHDRS {
	bios_bss PT_LOAD AT (0x7000);
	bios_data PT_LOAD AT (0x7800);
	bios_rodata PT_LOAD AT (0x6800);
	bios_code PT_LOAD AT (0x0000);
}

SECTIONS {
	.text: {
		. = 0x0000;
		*(.text);
		_etext = .;
	} >BIOS_CODE
	.bss: {
		. = 0x7000;
		_start_bss = .;
		_SDA_BASE_ = .;
		*(.bss);
		_end_bss = .;
	} >BIOS_BSS
	.data: {
		. = 0x7800;
		_start_data = .;
		*(.data);
		_end_data = .;
	} >BIOS_DATA
	.rodata: {
		. = 0x6800;
		_start_rodata = .;
		*(.rodata);
		_end_rodata = .;
	} >BIOS_RODATA
}
