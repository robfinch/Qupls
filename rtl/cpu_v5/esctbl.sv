// Exception table is organized as 64 vectors, 16 for each operating mode.
// caus is the exception cause code from 0 to 15
// A set bit in the escalation register indicates to escalate the exception
// to next operating level.

reg [15:0] escreg [0:3]		// Tracks which exceptions are escalated
reg [1:0] etbl_to_read;

case(operating_mode)
OM_APP:
	begin
		etbl_to_read = OM_APP;
		if (escreg[OM_APP][caus]) begin
			etbl_to_read = OM_SUPER;					// fetch vector from supervisor table
			if (escreg[OM_SUPER][caus]) begin	// If escalation bit is set
				etbl_to_read = OM_HYPER;				// fetch vector from hypervisor table
				if (escreg[OM_HYPER][caus])			// if escalation bit is set
					etbl_to_read = OM_SECURE;			// fetch vector from secure table
			end
		end
	end
OM_SUPER:
	begin
		etbl_to_read = OM_SUPER;					// fetch vector from supervisor table
		if (escreg[OM_SUPER][caus]) begin	// If escalation bit is set
			etbl_to_read = OM_HYPER;			// fetch vector from hypervisor table
			if (escreg[OM_HYPER][caus])		// if escalation bit is set
				etbl_to_read = OM_SECURE;		// fetch vector from secure table
		end
	end
OM_HYPER:
	begin
		etbl_to_read = OM_HYPER;			// fetch vector from hypervisor table
		if (escreg[OM_HYPER][caus])		// if escalation bit is set
			etbl_to_read = OM_SECURE;			// fetch vector from secure table
	end
OM_SECURE:
	begin
		etbl_to_read = OM_SECURE;			// fetch vector from secure table
	end
endcase

// Load vector from selected table in memory - issue jump vector micro-op
// trap_vector points to the exception table in memory for a given mode

	ea = trap_vector[etbl_to_read][caus];
