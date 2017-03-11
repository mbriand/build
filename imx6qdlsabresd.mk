################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 32
override COMPILE_NS_KERNEL := 32
override COMPILE_S_USER    := 32
override COMPILE_S_KERNEL  := 32

-include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################

PLATFORM_VARIANT ?= mx6qsabresd
ifeq ($(PLATFORM_VARIANT),mx6dlsabresd)
	LINUX_DTB_NAME		?= imx6dl-sabresd.dtb
else
	LINUX_DTB_NAME		?= imx6q-sabresd.dtb
endif

U-BOOT_PATH		?= $(ROOT)/u-boot
U-BOOT_BIN		?= $(U-BOOT_PATH)/u-boot.imx
U-BOOT_ENV		?= $(ROOT)/build/imx6/boot.txt
U-BOOT_PATCH		?= $(ROOT)/build/imx6/uboot-reserve-tee-memory.patch

LINUX_IMAGE		?= $(LINUX_PATH)/arch/arm/boot/zImage
LINUX_DTB		?= $(LINUX_PATH)/arch/arm/boot/dts/$(LINUX_DTB_NAME)
MODULE_OUTPUT		?= $(ROOT)/module_output

################################################################################
# Targets
################################################################################
all: optee-os optee-client xtest u-boot linux update_rootfs u-boot u-boot-script
all-clean: busybox-clean u-boot-clean optee-os-clean optee-client-clean u-boot-script-clean

-include toolchain.mk

################################################################################
# Das U-Boot
################################################################################

U-BOOT_EXPORTS ?= CROSS_COMPILE=$(AARCH32_CROSS_COMPILE) ARCH=arm

.PHONY: u-boot
u-boot:
	cd $(U-BOOT_PATH); patch --forward -p1 < $(U-BOOT_PATCH) || true
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) $(PLATFORM_VARIANT)_defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) tools

u-boot-script: u-boot
	$(U-BOOT_PATH)/tools/mkimage -T script -C none \
		-n 'U-Boot Script File' -d $(U-BOOT_ENV) boot.scr

u-boot-clean:
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

u-boot-script-clean:
	rm boot.scr


################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET = imx6qdlsabresd
BUSYBOX_CLEAN_COMMON_TARGET = imx6qdlsabresd clean

busybox: busybox-common

busybox-clean: busybox-clean-common

busybox-cleaner: busybox-cleaner-common
################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm/configs/imx_v6_v7_defconfig \
		$(CURDIR)/kconfigs/imx6qdlsabresd.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm

linux: linux-common

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=imx-$(PLATFORM_VARIANT) CFG_NS_ENTRY_ADDR=0x12000000 CFG_DT=y
optee-os: optee-os-common u-boot
	$(AARCH32_CROSS_COMPILE)objcopy -O binary \
		$(OPTEE_OS_PATH)/out/arm/core/tee.elf \
		$(OPTEE_OS_PATH)/optee.bin
	$(U-BOOT_PATH)/tools/mkimage -A arm -O linux -C none -a 0x4e000000 \
		-e 0x4e000000 -d $(OPTEE_OS_PATH)/optee.bin \
		$(OPTEE_OS_PATH)/uTee

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=imx-$(PLATFORM_VARIANT)
optee-os-clean: optee-os-clean-common
	rm $(OPTEE_OS_PATH)/optee.bin $(OPTEE_OS_PATH)/uTee

optee-client: optee-client-common

optee-client-clean: optee-client-clean-common
################################################################################
# xtest / optee_test
################################################################################
xtest: xtest-common

xtest-clean: xtest-clean-common

xtest-patch: xtest-patch-common

################################################################################
# hello_world
################################################################################
helloworld: helloworld-common

helloworld-clean: helloworld-clean-common

################################################################################
# Root FS
################################################################################
filelist-tee: filelist-tee-common

.PHONY: update_rootfs
update_rootfs: update_rootfs-common

.PHONY: run
run: flash

.PHONY: flash
flash:
	@echo "Create a SD card using following procedure"
	@echo
	@echo "Partition the SD card to have a FAT32 and an ext partitions,"
	@echo "starting at least 1MB after the beginning"
	@echo "Then run following commands:"
	@echo "dd if=../u-boot/u-boot.imx of=/dev/sdX bs=512 seek=2 conv=fsync"
	@echo "mkdir -p /mnt/tmp/"
	@echo "sudo mount /dev/sdX1 /mnt/tmp/"
	@echo "sudo cp boot.scr /mnt/tmp/"
	@echo "sudo cp $(LINUX_IMAGE) /mnt/tmp/"
	@echo "sudo cp $(LINUX_DTB) /mnt/tmp/"
	@echo "sudo cp $(OPTEE_OS_PATH)/uTee /mnt/tmp/"
	@echo "sudo umount /mnt/tmp/"
	@echo "sudo mount /dev/sdX2 /mnt/tmp/"
	@echo "cd /mnt/tmp/"
	@echo "gunzip -cd <repo directory>/gen_rootfs/filesystem.cpio.gz | sudo cpio -idm"
	@echo "cd -"
	@echo "sudo umount /mnt/tmp/"

