#sudo dd if=floppy.img of=/dev/sdb bs=4M
clear
echo "\nKinux compiller 0.01"
echo "----------------------------------\n"

echo "Author - Misha Bessonov a.k.a Hydrogen"
echo "GitHub - None\n"

echo "[KINUX ] Remove  - temp files..."
rm -r floppy.img __kernel.bin boot.bin >/dev/null

echo "[KINUX ] Compile - boot sector..."
nasm -f bin -o boot.bin boot.asm

echo "[KINUX ] Compile - kernel...\n"
nasm -f bin -o __kernel.bin kernel.asm

echo "[DEBUG ] Output file name: floppy.img\n"
mkdosfs -C floppy.img 1440 >/dev/null

echo "[KINUX ] Recording Kinux in file...\n"
dd conv=notrunc if=boot.bin of=floppy.img
mcopy -i floppy.img __kernel.bin ::/

echo "[DEBUG ] Testing Kinux"
qemu-system-i386 -fda floppy.img >/dev/null

echo "[AUTHOR] Have a nice day.\n"
