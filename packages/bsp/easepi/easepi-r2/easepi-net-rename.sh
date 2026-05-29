#!/bin/bash
# EasePi-R2: resolve eth naming conflicts by three-way swap
# reads PCIe address order from DT eth_order or /etc/eth_order
# renames interfaces to eth0..eth3 matching the physical port labels

rename_iface() {
	local old_name="$1"
	local new_name="$2"
	if [ -z "$old_name" ] || [ -z "$new_name" ]; then
		return 1
	fi
	if [ "$old_name" = "$new_name" ]; then
		return 0
	fi
	ip link set "$old_name" down 2>/dev/null
	ip link set "$old_name" name "$new_name" 2>/dev/null
}

rename_only() {
	local index=0
	local iface toiface
	while [[ -n "$1" ]]; do
		toiface="eth$index"
		iface=$1
		if [[ -n "$iface" && "$iface" != "$toiface" ]]; then
			rename_iface $toiface rename_tmp 2>/dev/null
			rename_iface $iface $toiface
			rename_iface rename_tmp $iface 2>/dev/null
		fi
		index=$(( $index + 1 ))
		shift
	done
}

get_iface_by_pcie() {
	local pcie_addr="$1"
	local net_dir="/sys/bus/pci/devices/${pcie_addr}/net"
	if [ -d "$net_dir" ]; then
		ls "$net_dir" 2>/dev/null | head -1
	fi
}

reorder_eth() {
	local pcie_addrs=("$@")
	local iface_list=()

	for addr in "${pcie_addrs[@]}"; do
		local iface
		for i in $(seq 1 10); do
			iface=$(get_iface_by_pcie "$addr")
			if [ -n "$iface" ]; then
				break
			fi
			sleep 0.5
		done
		iface_list+=("$iface")
	done

	rename_only "${iface_list[@]}"
}

if [ -s /proc/device-tree/eth_order ]; then
	reorder_eth $(tr -d '\0' < /proc/device-tree/eth_order | tr ',' ' ')
elif [ -s /sys/firmware/devicetree/base/eth_order ]; then
	reorder_eth $(tr -d '\0' < /sys/firmware/devicetree/base/eth_order | tr ',' ' ')
elif [ -s /etc/eth_order ]; then
	reorder_eth $(cat /etc/eth_order | tr ',' ' ')
else
	echo "easepi-net-rename: no eth_order found, nothing to do"
	exit 0
fi