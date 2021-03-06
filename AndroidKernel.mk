#Android makefile to build kernel as a part of Android Build
PERL		= perl

KERNEL_TARGET := $(strip $(INSTALLED_KERNEL_TARGET))
ifeq ($(KERNEL_TARGET),)
INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel
endif

ifeq ($(TARGET_PREBUILT_KERNEL),)

KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config
ifeq ($(TARGET_KERNEL_APPEND_DTB), true)
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/arm/boot/zImage-dtb
else
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/arm/boot/zImage
endif
KERNEL_HEADERS_INSTALL := $(KERNEL_OUT)/usr
KERNEL_MODULES_INSTALL := system
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules
KERNEL_IMG=$(KERNEL_OUT)/arch/arm/boot/Image

DTS_NAMES ?= $(shell $(PERL) -e 'while (<>) {$$a = $$1 if /CONFIG_ARCH_((?:MSM|QSD|MPQ)[a-zA-Z0-9]+)=y/; $$r = $$1 if /CONFIG_MSM_SOC_REV_(?!NONE)(\w+)=y/; $$arch = $$arch.lc("$$a$$r ") if /CONFIG_ARCH_((?:MSM|QSD|MPQ)[a-zA-Z0-9]+)=y/} print $$arch;' $(KERNEL_CONFIG))
KERNEL_USE_OF ?= $(shell $(PERL) -e '$$of = "n"; while (<>) { if (/CONFIG_USE_OF=y/) { $$of = "y"; break; } } print $$of;' kernel/arch/arm/configs/$(KERNEL_DEFCONFIG))

ifeq "$(KERNEL_USE_OF)" "y"
# LGE_CHANGED_BEGIN
# dts path change
# jungsu06.kim@lge.com
#DTS_FILES = $(wildcard $(TOP)/kernel/arch/arm/boot/dts/$(DTS_NAME)*.dts)
DTS_FILES = $(wildcard $(TOP)/kernel/arch/arm/boot/dts/$(DTS_TARGET)/$(DTS_NAME)*.dts)
# LGE_CHANGED_END

DTS_FILE = $(lastword $(subst /, ,$(1)))
DTB_FILE = $(addprefix $(KERNEL_OUT)/arch/arm/boot/,$(patsubst %.dts,%.dtb,$(call DTS_FILE,$(1))))
ZIMG_FILE = $(addprefix $(KERNEL_OUT)/arch/arm/boot/,$(patsubst %.dts,%-zImage,$(call DTS_FILE,$(1))))
KERNEL_ZIMG = $(KERNEL_OUT)/arch/arm/boot/zImage
DTC = $(KERNEL_OUT)/scripts/dtc/dtc

define append-dtb
mkdir -p $(KERNEL_OUT)/arch/arm/boot;\
$(foreach DTS_NAME, $(DTS_NAMES), \
   $(foreach d, $(DTS_FILES), \
      $(DTC) -p 1024 -O dtb -o $(call DTB_FILE,$(d)) $(d); \
      cat $(KERNEL_ZIMG) $(call DTB_FILE,$(d)) > $(call ZIMG_FILE,$(d));))
endef
else

define append-dtb
endef
endif

ifeq ($(TARGET_USES_UNCOMPRESSED_KERNEL),true)
$(info Using uncompressed kernel)
TARGET_PREBUILT_KERNEL := $(KERNEL_OUT)/piggy
else
TARGET_PREBUILT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)
endif

define mv-modules
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`;\
ko=`find $$mpath/kernel -type f -name *.ko`;\
for i in $$ko; do mv $$i $(KERNEL_MODULES_OUT)/; done;\
fi
endef

define clean-module-folder
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`; rm -rf $$mpath;\
fi
endef

# VMware_S
MVPD_MODULES := mvpkm.ko commkm.ko pvtcpkm.ko oektestkm.ko
define rm-mvp-modules
if [ "$(strip $(USES_VMWARE_VIRTUALIZATION))" = "true" ];then\
rm -f $(addprefix $(KERNEL_MODULES_OUT)/,$(MVPD_MODULES));\
fi
endef
# VMware_E

$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)

# porting bootchart2 to android
ifeq ($(INIT_BOOTCHART2),true)
KERNEL_DEFCONFIG_PATH:=kernel/arch/arm/configs/$(KERNEL_DEFCONFIG)
KERNEL_DEFCONFIG_BC2_PATH:=kernel/arch/arm/configs/bc2_$(KERNEL_DEFCONFIG)

bootchart2defconfig:
	cp -f $(KERNEL_DEFCONFIG_PATH) $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_TASKSTATS=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_TASK_DELAY_ACCT=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_TASK_XACCT=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_TASK_IO_ACCOUNTING=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_CONNECTOR=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)
	echo "CONFIG_PROC_EVENTS=y" >> $(KERNEL_DEFCONFIG_BC2_PATH)


$(KERNEL_CONFIG): $(KERNEL_OUT) bootchart2defconfig
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- bc2_$(KERNEL_DEFCONFIG)
else

$(KERNEL_CONFIG): $(KERNEL_OUT)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- $(KERNEL_DEFCONFIG)
# LGE_CHANGE_BEGIN
# sending rssi data to usb port
# RF_SW kyuhyung.lee
ifneq ($(TARGET_BUILD_VARIANT), user)
	echo "CONFIG_LGE_RSSI_DEBUG=y" >> $(KERNEL_CONFIG)
# VMware_S
ifeq ($(strip $(USES_VMWARE_VIRTUALIZATION)), true)
	echo "CONFIG_VMWARE_MVP_DEBUG=y" >> $(KERNEL_CONFIG)
	echo "CONFIG_VMWARE_PVTCP_DEBUG=y" >> $(KERNEL_CONFIG)
endif
# VMware_E
endif
# LGE_CHANGE_END
endif
# porting bootchart2 to android

#[BRCM][WAPI][CHINA]Broadcom chipset yongcan.guo for CHINA WAPI  CONFIG_BRCM_WAPI=y
ifeq ($(TARGET_COUNTRY),CN)
	echo "CONFIG_BRCM_WAPI=y" >> $(KERNEL_CONFIG)
endif

$(KERNEL_OUT)/piggy : $(TARGET_PREBUILT_INT_KERNEL)
	$(hide) gunzip -c $(KERNEL_OUT)/arch/arm/boot/compressed/piggy.gzip > $(KERNEL_OUT)/piggy

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_OUT) $(KERNEL_CONFIG) $(KERNEL_HEADERS_INSTALL)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi-
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- modules
	$(MAKE) -C kernel O=../$(KERNEL_OUT) INSTALL_MOD_PATH=../../$(KERNEL_MODULES_INSTALL) INSTALL_MOD_STRIP=1 ARCH=arm CROSS_COMPILE=arm-eabi- modules_install
	
ifeq ($(PRODUCT_SUPPORT_EXFAT), y)
ifneq ($(PRODUCT_SUPPORT_OPEN_EXFAT), y)
	@cp -f $(ANDROID_BUILD_TOP)/kernel/tuxera_update.sh $(ANDROID_BUILD_TOP)
	@sh tuxera_update.sh --target target/lg.d/mobile-mtp-3014.9.10 --use-cache --latest --max-cache-entries 2 --source-dir $(ANDROID_BUILD_TOP)/kernel --output-dir $(ANDROID_BUILD_TOP)/$(KERNEL_OUT) -a --user lg-mobile --pass AumlTsj0ou
	@tar -xzf tuxera-exfat*.tgz
	@mkdir -p $(TARGET_OUT_EXECUTABLES)
	@cp $(ANDROID_BUILD_TOP)/tuxera-exfat*/exfat/kernel-module/texfat.ko $(ANDROID_BUILD_TOP)/$(TARGET_OUT_EXECUTABLES)/../lib/modules/
	@cp $(ANDROID_BUILD_TOP)/tuxera-exfat*/exfat/tools/* $(TARGET_OUT_EXECUTABLES)
	@rm -f kheaders*.tar.bz2
	@rm -f tuxera-exfat*.tgz
	@rm -rf tuxera-exfat*
	@rm -f tuxera_update.sh
endif
 ifeq ($(PRODUCT_SUPPORT_NTFS), y)
	@cp -f $(ANDROID_BUILD_TOP)/kernel/tuxera_update.sh $(ANDROID_BUILD_TOP)
	@sh tuxera_update.sh --target target/lg.d/mobile-msm8926-arm32-4.8 --use-cache --latest --source-dir $(ANDROID_BUILD_TOP)/kernel --output-dir $(ANDROID_BUILD_TOP)/$(KERNEL_OUT) -a --user lg-mobile --pass AumlTsj0ou
	@tar -xzf tuxera-file*.tgz
	@mkdir -p $(TARGET_OUT_EXECUTABLES)
	@cp $(ANDROID_BUILD_TOP)/tuxera-file*/ntfs/kernel-module/tntfs.ko $(ANDROID_BUILD_TOP)/$(TARGET_OUT_EXECUTABLES)/../lib/modules/
	@cp $(ANDROID_BUILD_TOP)/tuxera-file*/ntfs/tools/* $(TARGET_OUT_EXECUTABLES)
	@rm -f kheaders*.tar.bz2
	@rm -f tuxera-file*.tgz
	@rm -rf tuxera-file*
	@rm -f tuxera_update.sh
 endif
endif
	$(mv-modules)
	$(clean-module-folder)
# VMware_S
	$(rm-mvp-modules)
# VMware_E
	$(append-dtb)

$(KERNEL_HEADERS_INSTALL): $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- headers_install

kerneltags: $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- tags

kernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- menuconfig
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- savedefconfig
	cp $(KERNEL_OUT)/defconfig kernel/arch/arm/configs/$(KERNEL_DEFCONFIG)

endif
