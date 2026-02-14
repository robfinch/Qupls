ENTRY (_start)

MEMORY {
	BRAM : ORIGIN = 0x0000, LENGTH = 32k
}

PHDRS {
	copro_bram PT_LOAD AT (0x0000);
}

SECTIONS {
	.bram: {
		. = 0x0000;
		*(.bram);
		_etext = .;
	} >BRAM
}
