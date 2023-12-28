
/* Display blinking LEDs while delaying to show CPU is working.
*/
private void Delay3s(void)
{
	__int64* leds = 0x0FEDFFF00;
	int cnt;
	
	for (cnt = 0; cnt < 300000; cnt++)
		leds[0] = cnt >> 17;
}

public void bootrom(void)
{
	int* PTBR = 0xfff4ff20;
	int* pgtbl = 0xfff80000;
	int cnt;
	__int32* pRand;

	*PTBR = 0xfff80000;	
	pRand = 0xFEE1FD00;
	
	__sync(0x0FFFF);
	/* clear out page table */
	for (cnt = 0; cnt < 16; cnt++) {
		pgtbl[cnt] = 0;
	}
	pgtbl[0x1EDF] = 0x83000FFFFFFFFEDF;	/* LEDs */
	pgtbl[0x1EC0] = 0x83000FFFFFFFFEC0;	/* text mode screen */
	pgtbl[0x1EDC] = 0x83000FFFFFFFFEDC;	/* Keyboard */
	pgtbl[0x1EE1] = 0x83000FFFFFFFFEE1;	/* random number generator */
	__sync(0x0FFFF);
	cnt = sizeof(pRand[1]);
	pRand[1] = 0;						/* select random stream #0 */
	pRand[2] = 0x99999999;	/* set random seed value */
	pRand[3] = 0x99999999;
	Delay3s();
}
