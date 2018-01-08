SHELL=/bin/bash -O extglob -c
PROJROOT = $(realpath .)
SRC = $(PROJROOT)/src
ROOT_SKEL = $(PROJROOT)/root-skel
ROOT = $(PROJROOT)/root
EFIROOT = $(PROJROOT)/efiroot
BUILD = $(PROJROOT)/build
CC = /usr/bin/gcc
THREADS = 12
QEMU_RAM = 512
QEMU_CPUS = 4
MAKE = /usr/bin/make -j$(THREADS)
DISKIMG = $(BUILD)/disk.img
PARTIMG = $(BUILD)/part.img
DISKSECTS = 204800
STARTSECT = 2048
ENDSECT = 204766
PARTSECTS = 202720
EFIBIOS = $(SRC)/uefi.bin
BOOTEFIPATH = EFI/BOOT
BOOTEFINAME = BOOTX64.EFI
BOOTEFIFILE = $(BOOTEFIPATH)/$(BOOTEFINAME)

all: $(BUILD)/kernel

clean:
	rm -rf $(EFIROOT) $(BUILD) $(ROOT)

$(ROOT)/.fs_ready:
	cp -r $(ROOT_SKEL) $(ROOT)
	mkdir -p $(BUILD) $(ROOT)/{dev,home,proc,root,sys,tmp,var/{log,tmp}}
	touch $(ROOT)/.fs_ready

libs_install: openssl_install

apps_install: $(ROOT)/.fs_ready $(ROOT)/bin/busybox $(ROOT)/bin/docker

# Kernel
$(SRC)/linux/.config:
	cp configs/linux $(SRC)/linux/.config

$(SRC)/linux/kernel/configs.ko: $(SRC)/linux/.config
	cd $(SRC)/linux && $(MAKE) modules

$(ROOT)/lib/modules: $(SRC)/linux/kernel/configs.ko
	cd $(SRC)/linux && $(MAKE) INSTALL_MOD_PATH=$(ROOT) modules_install

$(SRC)/linux/arch/x86/boot/bzImage: apps_install $(ROOT)/lib/modules
	cd $(SRC)/linux && $(MAKE) bzImage

$(BUILD)/kernel: $(SRC)/linux/arch/x86/boot/bzImage
	cp $(SRC)/linux/arch/x86/boot/bzImage $(BUILD)/kernel

#$(BUILD)/initramfs: apps_install
#	cd $(ROOT) && find | cpio --owner=0:0 -oH newc | gzip > $(BUILD)/initramfs && cd ..

# Software

# busybox

$(SRC)/busybox/busybox: $(SRC)/busybox/.config
	cd $(SRC)/busybox && $(MAKE) DESTDIR=$(ROOT)

$(ROOT)/bin/busybox: $(SRC)/busybox/busybox
	cd $(SRC)/busybox && $(MAKE) install

$(SRC)/busybox/.config:
	cp configs/busybox $(SRC)/busybox/.config

# Docker

$(ROOT)/bin/docker:
	echo Stub

# Filesystem
$(EFIROOT)/$(BOOTEFIFILE): $(BUILD)/kernel
	mkdir -p $(EFIROOT)/$(BOOTEFIPATH)
	cp $(BUILD)/kernel $(EFIROOT)/$(BOOTEFIFILE)

# UEFI Boot image compilation
makedisk:
	dd if=/dev/zero of=$(DISKIMG) bs=512 count=$(DISKSECTS)

partdisk: makedisk
	sgdisk -o -n 1:$(STARTSECT):$(ENDSECT) -t 1:ef00 -c 1:"EFI System" -p $(DISKIMG)

makepart:
	dd if=/dev/zero of=$(PARTIMG) bs=512 count=$(PARTSECTS)
	mkfs.vfat -F32 $(PARTIMG)

copytopart: makepart $(BUILD)/kernel
	mmd -i $(PARTIMG) ::/EFI
	mmd -i $(PARTIMG) ::/EFI/BOOT
	mcopy -i $(PARTIMG) $(BUILD)/kernel ::/EFI/BOOT/BOOTX64.EFI

bootimg: partdisk copytopart
	dd if=$(PARTIMG) of=$(DISKIMG) bs=512 seek=2048 count=$(PARTSECTS) conv=notrunc

# Emulation

qemuraw: $(BUILD)/kernel # $(BUILD)/initramfs
	qemu-system-x86_64 -cpu qemu64 -kernel $(BUILD)/kernel -m $(QEMU_RAM) -smp $(QEMU_CPUS) #-initrd $(BUILD)/initramfs -append "root=/dev/ram0"

qemuefi: $(EFIBIOS) bootimg
	qemu-system-x86_64 -cpu qemu64 -bios $(EFIBIOS) -drive file=$(DISKIMG),format=raw -m $(QEMU_RAM) -smp $(QEMU_CPUS)

qemuefifat: $(EFIBIOS) $(EFIROOT)/$(BOOTEFIFILE)
	qemu-system-x86_64 -cpu qemu64 -bios $(EFIBIOS) -drive file=fat:rw:$(EFIROOT) -m $(QEMU_RAM) -smp $(QEMU_CPUS)
