all: for_bios.bin clean

min_boot.bin: min_boot.asm
	fasm min_boot.asm

protected.bin: protected.asm
	fasm protected.asm

for_bios.bin: min_boot.bin protected.bin
	dd if=min_boot.bin of=for_bios.bin
	dd if=protected.bin of=for_bios.bin seek=1

clean:
	rm min_boot.bin protected.bin

run: for_bios.bin
	kvm for_bios.bin
