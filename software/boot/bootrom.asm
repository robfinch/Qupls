   
	.text
	.align	5
 
#{++ _Delay3s
	.sdreg	60
	.sd2reg	59
_Delay3s:
  sub sp,sp,32
  sto fp,[sp]
  mov fp,sp
  sto lr1,16[fp]
  sub sp,sp,48
  sto s0,[sp]
  sto s1,8[sp]
# __int64* leds = 0x0FEDFFF00;
  ldi s1,1048320
  orm s1,4077
# for (cnt = 0; cnt < 300000; cnt++)
  mov s0,r0
  ldi t1,300000
  bge s0,t1,.00016
.00015:
# leds[0] = cnt >> 17;
  asr t0,s0,17
  sto t0,[s1]
.00017:
  add s0,s0,1
  blt s0,t1,.00015
.00016:
.00014:
  ldo s0,[sp]
  ldo s1,8[sp]
  mov sp,fp
  ldo fp,[sp]
  rtd sp,sp,32
	.type	_Delay3s,@function
	.size	_Delay3s,$-_Delay3s


	.bss
	.align	14

#--}
   
	.text
	.align	5
   
#{++ _bootrom

	.align 5

	.sdreg	60
	.sd2reg	59
_bootrom:
  sub sp,sp,32
  sto fp,[sp]
  mov fp,sp
  sto lr1,16[fp]
  sub sp,sp,64
  bsr lr2,__store_s0s3
# int* PTBR = 0xfff4ff20;
  ldi s3,327456
  orm s3,4095
  ldi s1,524288
  orm s1,4095
# *PTBR = 0xfff80000;
  ldi t0,524288
  orm t0,4095
  sto t0,[s3]
# pRand = 0xFEE1FD00;
  ldi s2,130304
  orm s2,4078
# __sync(0x0FFFF);
  sync 65535
# for (cnt = 0; cnt < 16; cnt++) {
  mov s0,r0
  ldi t1,16
  bge s0,t1,.00032
.00031:
# pgtbl[cnt] = 0;
  sto r0,0[s1+s0*]
.00033:
  add s0,s0,1
  blt s0,t1,.00031
.00032:
# pgtbl[0x1EDF] = 0x83000FFFFFFFFEDF;	/* LEDs */
  ldi t0,1048287
  orm t0,16777215
  orh t0,16265216
  sto t0,63224[s1]
# pgtbl[0x1EC0] = 0x83000FFFFFFFFEC0;	/* text mode screen */
  ldi t0,1048256
  orm t0,16777215
  orh t0,16265216
  sto t0,62976[s1]
# pgtbl[0x1EDC] = 0x83000FFFFFFFFEDC;	/* Keyboard */
  ldi t0,1048284
  orm t0,16777215
  orh t0,16265216
  sto t0,63200[s1]
# pgtbl[0x1EE1] = 0x83000FFFFFFFFEE1;	/* random number generator */
  ldi t0,1048289
  orm t0,16777215
  orh t0,16265216
  sto t0,63240[s1]
# __sync(0x0FFFF);
  sync 65535
# cnt = sizeof(pRand[1]);
  ldi s0,4
# pRand[1] = 0;						/* select random stream #0 */
  stt r0,4[s2]
# pRand[2] = 0x99999999;	/* set random seed value */
  ldi t0,629145
  orm t0,2457
  stt t0,8[s2]
# pRand[3] = 0x99999999;
  orm t0,2457
  stt t0,12[s2]
# Delay3s();
  bsr _Delay3s
.00030:
  bsr lr2,__load_s0s3
  ldo lr1,16[fp]
  mov sp,fp
  ldo fp,[sp]
  rtd sp,sp,32
	.type	_bootrom,@function
	.size	_bootrom,$-_bootrom


	.bss
	.align	14

#--}

	.rodata
	.align	14

	.extern	_start_bss
	.global	_bootrom
	.extern	_start_rodata
	.extern	_start_data
