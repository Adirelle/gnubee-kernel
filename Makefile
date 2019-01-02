
GITREF := $(shell git -C linux rev-parse --abbrev-ref HEAD | cut -d/ -f2)

BASEDIR = $(shell readlink -f .)
SRCDIR := $(shell readlink -f linux)

GNUBEE := root@192.168.0.1
TARGET_PATH := GB-PCx_uboot-$(GITREF).bin
KCF := gnubee1_defconfig

-include Makefile.local

PATH := /opt/cross/bin:$(PATH)
ARCH := mips
CROSS_COMPILE := mipsel-unknown-linux-gnu-
O := $(BASEDIR)/build/$(GITREF)
export PATH ARCH CROSS_COMPILE O

WORKDIR := $O

VMLINUX_PATH := $(WORKDIR)/vmlinux
UIMAGE_PATH := $(WORKDIR)/arch/mips/boot/uImage 

MKINITRAMFS_NAME = mkgnubee-initramfs.sh
MKINITRAMFS_PATH = $(BASEDIR)/$(MKINITRAMFS_NAME)

INITRAMFS_NAME = gnubee-initramfs.tgz 
INITRAMFS_PATH = $(BASEDIR)/$(INITRAMFS_NAME)

INITRAMFS_DIR = $(SRCDIR)/initramfs

.phony: all clean mrproper defconfig menuconfig

all: $(TARGET_PATH)

clean:
	rm -rf $(INITRAMFS_PATH) $(INITRAMFS_DIR) $(UIMAGE_PATH)

mrproper: clean
	make -C $(SRCDIR) O=$O mrproper

defconfig: $(WORKDIR)/.config

$(WORKDIR)/.config: $(SRCDIR)/arch/mips/configs/$(KCF) | $(WORKDIR)
	make -C $(SRCDIR) O=$O $(KCF)

menuconfig: | $(WORKDIR)/.config
	make -C $(SRCDIR) O=$O menuconfig

$(WORKDIR) $(INITRAMFS_DIR):
	mkdir -p $@

$(VMLINUX_PATH): $(WORKDIR)/.config | $(INITRAMFS_DIR)
	make -C $(SRCDIR) O=$O -j`nproc`

$(INITRAMFS_PATH): $(MKINITRAMFS_PATH)
	scp $< $(GNUBEE):$(MKINITRAMFS_NAME)
	ssh $(GNUBEE) sh -lc ./$(MKINITRAMFS_NAME)
	scp $(GNUBEE):$(INITRAMFS_NAME) $@

$(INITRAMFS_DIR)/init: $(INITRAMFS_PATH) | $(INITRAMFS_DIR)
	tar xzf $(INITRAMFS_PATH) -C $(SRCDIR)

$(INITRAMFS_DIR)/lib/modules: $(VMLINUX_PATH) | $(INITRAMFS_DIR)
	make -C $(SRCDIR) O=$O INSTALL_MOD_PATH=$(INITRAMFS_DIR) modules_install

$(UIMAGE_PATH): $(INITRAMFS_DIR)/init $(INITRAMFS_DIR)/lib/modules
	make -C $(SRCDIR) O=$O uImage

$(TARGET_PATH): $(UIMAGE_PATH) $(VMLINUX_PATH) 
	cp $< $@

