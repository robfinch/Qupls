import fta_bus_pkg::fta_imessage_t;

package msi_pkg;

typedef struct packed
{
	logic [15:0] resv2;
	logic [7:0] cpu_affinity_group;
	logic [2:0] resv1;
	logic [2:0] swstk;		// software stack required
	logic ie;							// 1=interrupt enabled
	logic ai;							// 0=address, 1=instruction
	logic [95:0] adrins;	// ISR address or instruction
} msi_vec_t;						// 128 bits

typedef struct packed
{
	logic [23:0] timestamp;
	fta_bus_pkg::fta_imessage_t msg;
} irq_hist_t;

endpackage
