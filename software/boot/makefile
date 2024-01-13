#
PATH = $PATH;F:\cores2023\Qupls\software\CC64\cc64\cc64\debug;"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.28.29333\bin\Hostx64\x64\bin\Hostx64\x64\"
INC = F:\cores2023\Qupls\software\source\;F:\cores2023\Qupls\software\Femtiki\source\kernel\;F:\cores2023\Qupls\software\inc\
INCLUDE = D:\cores2023\Qupls\software\source\;F:\cores2023\Qupls\software\Femtiki\source\kernel\;F:\cores2023\Qupls\software\inc\
FPPINC  = D:\cores2023\Qupls\software\source\;F:\cores2023\Qupls\software\Femtiki\source\kernel\;F:\cores2023\Qupls\software\inc\
CXX = cc64
#CXX = opt
CFLAGS2 = -c99 -ID:\cores2023\Qupls\software\inc\ -O=31
#CFLAGS = -w -S -fno-exceptions
CFLAGS = -w -S -fno-exceptions -a21


#

BIOS:
	del boot_rom.bin
	del boot_rom.lst
	cc64 $(CFLAGS) bootrom.c
	cc64 $(CFLAGS) serial.c
	cc64 $(CFLAGS) SIEVE.c
	cc64 $(CFLAGS) printf_again.c
#	cc64 $(CFLAGS) os_stub.c

	vasmQupls_std_win32.exe -Fvobj -Lbpl=5 -L bootrom.lst bootrom.asm -o bootrom.o
	vasmQupls_std_win32.exe -Fvobj -Lbpl=5 -L serial.lst serial.asm -o serial.o
	vasmQupls_std_win32.exe -Fvobj -L boot.lst boot.asm -o boot.o
	vasmQupls_std_win32.exe -Fvobj -L reset_vector.lst reset_vector.asm -o reset_vector.o
	vasmQupls_std_win32.exe -Fvobj -L ramtest.lst ramtest.asm -o ramtest.o
	vasmQupls_std_win32.exe -Fvobj -L fibonacci.lst fibonacci.asm -o fibonacci.o
	vasmQupls_std_win32.exe -Fvobj -Lbpl=5 -L sieve.lst sieve.asm -o sieve.o
	vasmQupls_std_win32.exe -Fvobj -Lbpl=5 -L printf_again.lst printf_again.asm -o printf_again.o
	vasmQupls_std_win32.exe -Fvobj -Lbpl=5 -L ..\cc64rt\source\cc64rt.lst ..\cc64rt\source\cc64rt.asm -o cc64rt.o
	vasmQupls_std_win32.exe -Fvobj -Lbpl=5 -L ..\cc64rt\source\__store.lst ..\cc64rt\source\__store.asm -o __store.o
	vasmQupls_std_win32.exe -Fvobj -Lbpl=5 -L ..\cc64rt\source\__load.lst ..\cc64rt\source\__load.asm -o __load.o
#	vasmQupls_std_win32.exe -Fvobj -L LEDTest.lst LEDTest.asm -o LEDTest.o
#	vasmrf68000_mot_win32.exe -Fvobj -L cputest.lst cputest.asm -o cputest.o
#	vasmrf68000_mot_win32.exe -Fvobj -L boot.lst boot.asm -o boot.o -m68010
#	vasmm68k_std_win32.exe -Fvobj -L boot.lst boot.asm -o boot.o -m68010
#	vasmrfPhoenix_std_win32.exe -Fvobj -L add.lst add.asm -o add.o
	vlink -M -T rom_bios.cmd -brawbin1 boot.o cc64rt.o __store.o __load.o reset_vector.o -o boot.bin
	vlink -T ramtest.cmd -brawbin1 ramtest.o -o ramtest.bin
	vlink -T rom_bios.cmd -brawbin1 fibonacci.o -o fibonacci.bin
#	vlink -T rom_bios.cmd -brawbin1 __store.o __load.o printf_again.o sieve.o -o sieve.bin
#	vlink -T rom_bios.cmd -brawbin1 LEDTest.o -o LEDTest.bin
#	vlink -T rom_bios.cmd -brawbin1 cputest.o -o cputest.bin
#	vlink -T rom_bios.cmd -bsrec37 boot.o -o boot.s37
#	vlink -T rom_bios.cmd -brawbin1 boot.o -o boot.bin
#	vlink -T rom_bios.cmd -brawbin1 add.o -o add.bin
#	bin2ver fibonacci.bin 128 m
#	bin2ver fibonacci.bin 128
	bin2ver boot.bin 128 m
	bin2ver boot.bin 128
#	bin2ver LEDTest.bin 32 m
#	bin2ver boot.bin 32 m
#	bin2ver cputest.bin 32 m
#	bin2ver add.bin 128
