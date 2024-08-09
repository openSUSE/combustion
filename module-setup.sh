check() {
	# Omit if building for this already configured system
	if [[ $hostonly ]] && [ -e "${dracutsysrootdir}/etc/machine-id" ]; then
		return 255
	fi
	return 0
}

depends() {
	echo bash firstboot network systemd url-lib
}

install() {
	inst_simple "${moddir}/combustion.service" "${systemdsystemunitdir}/combustion.service"
	inst_simple "${moddir}/combustion-prepare.service" "${systemdsystemunitdir}/combustion-prepare.service"
	inst_simple "${moddir}/combustion.rules" "/etc/udev/rules.d/70-combustion.rules"
	$SYSTEMCTL -q --root "$initdir" enable combustion.service
	inst_multiple awk chroot findmnt grep rmdir systemd-detect-virt unshare wc
	inst_multiple -o base64 gzip vmware-rpctool
	inst_simple "${moddir}/combustion" "/usr/bin/combustion"

	# ignition-mount.service mounts stuff below /sysroot in ExecStart and umounts
	# it on ExecStop, failing if umounting fails. This conflicts with the
	# mounts/umounts done by combustion. Just let combustion do it instead.
	mkdir -p "${initdir}/${systemdsystemunitdir}/ignition-mount.service.d/"
	echo -e "[Service]\nExecStop=" > "${initdir}/${systemdsystemunitdir}/ignition-mount.service.d/noexecstop.conf"

	# Wait up to 10s (30s on aarch64) for the config drive
	devtimeout=10
	[ "$(uname -m)" = "aarch64" ] && devtimeout=30
	mkdir -p "${initdir}/${systemdsystemunitdir}/dev-combustion-config.device.d/"
	echo -e "[Unit]\nJobTimeoutSec=${devtimeout}" > "${initdir}/${systemdsystemunitdir}/dev-combustion-config.device.d/timeout.conf"
}

installkernel() {
	# Modules for config sources
	hostonly='' instmods ext4
	# hostonly is fine here, only include them if they fit the current HW
	instmods qemu_fw_cfg vmw_vsock_vmci_transport
}
