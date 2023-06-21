TOOLCHAIN_ENVIRONMENT = $(PWD)/../../toolchain/environment-setup-cortexa7t2hf-neon-vfpv4-ostl-linux-gnueabi
 
FIP_DEPLOYDIR_ROOT = $(PWD)/FIP_artifacts
TFA_DIR = $(PWD)/tf-a-stm32mp-v2.6-stm32mp1-r1-r0/tf-a-stm32mp-v2.6-stm32mp1-r1
OPTEE_DIR = $(PWD)/optee-os-stm32mp-3.16.0-stm32mp1-r1-r0/optee-os-stm32mp-3.16.0-stm32mp1-r1
UBOOT_DIR = $(PWD)/u-boot-stm32mp-v2021.10-stm32mp1-r1-r0/u-boot-stm32mp-v2021.10-stm32mp1-r1
LINUX_DIR = $(PWD)/linux-stm32mp-5.15.24-stm32mp1-r1-r0/linux-5.15.24
BUILDROOT_DIR = $(PWD)/buildroot-2022.02.5



all : permissions uboot tfa optee bootfs rootfs


tfa :
	cd $(TFA_DIR) && \
	. $(TOOLCHAIN_ENVIRONMENT) && \
	export FIP_DEPLOYDIR_ROOT=$(FIP_DEPLOYDIR_ROOT) && \
	make -f $(TFA_DIR)/../Makefile.sdk DEPLOYDIR=$(FIP_DEPLOYDIR_ROOT)/arm-trusted-firmware -j12 all

optee :
	cd $(OPTEE_DIR) && \
	. $(TOOLCHAIN_ENVIRONMENT) && \
	export FIP_DEPLOYDIR_ROOT=$(FIP_DEPLOYDIR_ROOT) && \
	make -f $(OPTEE_DIR)/../Makefile.sdk DEPLOYDIR=$(FIP_DEPLOYDIR_ROOT)/optee -j12 all

uboot :
	cd $(UBOOT_DIR) && \
	. $(TOOLCHAIN_ENVIRONMENT) && \
	export FIP_DEPLOYDIR_ROOT=$(FIP_DEPLOYDIR_ROOT) && \
	make -f $(UBOOT_DIR)/../Makefile.sdk DEPLOYDIR=$(FIP_DEPLOYDIR_ROOT)/u-boot -j12 all

linux : $(LINUX_DIR)/../build/.config
	cd $(LINUX_DIR)/../build && \
	. $(TOOLCHAIN_ENVIRONMENT) && \
	make ARCH=arm uImage vmlinux dtbs modules LOADADDR=0xC2000040 -j12

$(LINUX_DIR)/../build/.config :
	cd $(LINUX_DIR) && \
	. $(TOOLCHAIN_ENVIRONMENT) && \
	make ARCH=arm O="$(LINUX_DIR)/../build" stm32mp157d_100ask_defconfig

modules : linux
	cd $(LINUX_DIR)/../build && \
	. $(TOOLCHAIN_ENVIRONMENT) && \
	make ARCH=arm INSTALL_MOD_PATH="$(PWD)/100ask-rootfs-patch" modules_install

bootfs : permissions linux $(FIP_DEPLOYDIR_ROOT)/bootfs.ext4
	rm -rf boot
	mkdir boot
	sudo mount $(FIP_DEPLOYDIR_ROOT)/bootfs.ext4 boot
	sudo cp -f $(LINUX_DIR)/../build/arch/arm/boot/uImage boot/
	sudo cp -f $(LINUX_DIR)/../build/arch/arm/boot/dts/stm32mp157d-100ask.dtb boot/
	sudo umount boot
	rm -rf boot

$(FIP_DEPLOYDIR_ROOT)/bootfs.ext4 :
	cd $(FIP_DEPLOYDIR_ROOT) && dd if=/dev/zero of=bootfs.ext4 bs=1M count=32 && mkfs.ext4 -L bootfs bootfs.ext4

buildroot : $(BUILDROOT_DIR)/build/.config
	cd $(BUILDROOT_DIR)/build && make -j12

$(BUILDROOT_DIR)/build/.config :
	cd $(BUILDROOT_DIR) && make O="build" stm32mp157d_100ask_defconfig

rootfs : permissions linux buildroot
	cp -f $(BUILDROOT_DIR)/build/images/rootfs.ext4 $(FIP_DEPLOYDIR_ROOT)
	rm -rf root
	mkdir root
	sudo mount $(FIP_DEPLOYDIR_ROOT)/rootfs.ext4 root
	sudo cp -rf $(PWD)/100ask-rootfs-patch/* root/
	cd $(LINUX_DIR)/../build && . $(TOOLCHAIN_ENVIRONMENT) && sudo make ARCH=arm INSTALL_MOD_PATH="$(PWD)/root" modules_install
	sudo umount root
	rm -rf root

permissions  :
	sudo pwd

clean : 
	rm -rf buildroot-2022.02.5/build
	rm -rf optee-os-stm32mp-3.16.0-stm32mp1-r1-r0/build
	rm -rf tf-a-stm32mp-v2.6-stm32mp1-r1-r0/build
	rm -rf u-boot-stm32mp-v2021.10-stm32mp1-r1-r0/build
	rm -rf linux-stm32mp-5.15.24-stm32mp1-r1-r0/build
	rm -rf $(FIP_DEPLOYDIR_ROOT)/arm-trusted-firmware/*
	rm -rf $(FIP_DEPLOYDIR_ROOT)/optee/*
	rm -rf $(FIP_DEPLOYDIR_ROOT)/u-boot/*
	rm -rf $(FIP_DEPLOYDIR_ROOT)/fip/*
	rm -rf $(FIP_DEPLOYDIR_ROOT)/bootfs.ext4
	rm -rf $(FIP_DEPLOYDIR_ROOT)/rootfs.ext4