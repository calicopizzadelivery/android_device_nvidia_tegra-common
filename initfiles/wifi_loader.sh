#!/vendor/bin/sh

# Copyright (c) 2012-2018, NVIDIA CORPORATION. All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.


# vendor id defines
BRCM_SDIO=0x02d0
BRCM_PCIE=0x14e4
RTLK_PCIE=0x10ec

perform_enumeration() {
COUNT=0;
while [ $COUNT -le 2 ]; do
	#find hardware used and assigned corresponding mmc interface used for wifi chip
	for path in /sys/bus/sdio/devices/*; do
		vendor=$(cat $path/vendor)
		if [ "$vendor" = "$BRCM_SDIO" ]; then
			device=$(cat $path/device)
			/vendor/bin/log -t "wifiloader" -p i "WiFi SDIO VendorID: $vendor, DeviceID: $device"
			return;
		fi
	done
	for path in /sys/bus/pci/devices/*; do
		vendor=$(cat $path/vendor)
		if [ "$vendor" = "$BRCM_PCIE" -o "$vendor" = "$RTLK_PCIE" ]; then
			device=$(cat $path/device)
			/vendor/bin/log -t "wifiloader" -p i "WiFi PCIE VendorID: $vendor, DeviceID: $device"
			return;
		fi
	done
	/vendor/bin/log -t "wifiloader" -p e "WiFi card is not available! try $COUNT"
	sleep 2
	COUNT=$(($COUNT+1))
done
}

load_modules() {
COUNT=0;
if [ -e /vendor/lib/modules/bluedroid_pm.ko ]; then
	/vendor/bin/log -t "wifiloader" -p i "Bluedroid_pm driver compiled as module"
	while [ $COUNT -le 5 ]; do
		if [ '1' -eq `lsmod | grep -c bluedroid_pm` ]; then
			/vendor/bin/log -t "wifiloader" -p i "Bluedroid_pm driver loaded at $COUNT iteration"
			break
		fi
		sleep 1
		COUNT=$(($COUNT+1))
		if [ $COUNT -eq 5 ]; then
			/vendor/bin/log -t "wifiloader" -p e "Failed to detect Bluedroid_pm driver load"
		fi
	done
fi

if [ $device = "0x4354" ]; then
	if [ -e /vendor/lib/modules/bcmdhd.ko ]; then
		/vendor/bin/log -t "wifiloader" -p i "load bcmdhd module"
		insmod /vendor/lib/modules/bcmdhd.ko
	fi
elif [ $device = "0x4355" -o $device = "0x43ef" ]; then
	if [ -e /vendor/lib/modules/bcmdhd_pcie.ko ]; then
		/vendor/bin/log -t "wifiloader" -p i "load bcmdhd_pcie module"
		insmod /vendor/lib/modules/bcmdhd_pcie.ko
	fi
elif [ $device = "0xc822" ]; then
	# RTL8822CE. cfg80211 first: the Realtek driver is built against it and
	# nothing else pulls it in on a board with no Broadcom radio fitted.
	if [ -e /vendor/lib/modules/cfg80211.ko ]; then
		insmod /vendor/lib/modules/cfg80211.ko 2>/dev/null
	fi
	if [ -e /vendor/lib/modules/rtl8822ce.ko ]; then
		/vendor/bin/log -t "wifiloader" -p i "load rtl8822ce module"
		insmod /vendor/lib/modules/rtl8822ce.ko
	fi
fi
}

if [ -z $vendor ]; then
	/vendor/bin/log -t "wifiloader" -p e "WiFi auto card detection fail"
fi


if [ "`cat /proc/device-tree/brcmfmac_pcie_wlan/status`" = "okay" ]; then
       ln -sf /sys/module/brcmfmac/parameters/alternative_fw_path /data/vendor/wifi/fw_path
       ln -sf /sys/module/brcmfmac/parameters/alternative_fw_path /data/vendor/wifi/op_mode
elif [ "`cat /proc/device-tree/bcmdhd_wlan/status`" = "okay" ]; then
       ln -sf /sys/module/bcmdhd/parameters/firmware_path /data/vendor/wifi/fw_path
       ln -sf /sys/module/bcmdhd/parameters/op_mode /data/vendor/wifi/op_mode
else
       touch /data/vendor/wifi/fw_path
       touch /data/vendor/wifi/op_mode
fi
       chmod 0660 /data/vendor/wifi/fw_path
       chmod 0660 /data/vendor/wifi/op_mode
       chown wifi:wifi /data/vendor/wifi/fw_path
       chown wifi:wifi /data/vendor/wifi/op_mode
