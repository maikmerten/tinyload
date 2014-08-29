CA=ca65
LD=ld65

all: hex

hex: tinyload
	srec_cat rom.bin -binary -o rom.hex -intel

tinyload: tinyload.o
	$(LD) -C multicomp.config -m tinyload.map -vm -o rom.bin tinyload.o

tinyload.o: tinyload.asm math.asm macros.asm fat.asm io.asm util.asm
	$(CA) --listing tinyload.listing -o tinyload.o tinyload.asm

clean:
	rm -f *.o *.rom *.map *.lst *.bin *.hex
