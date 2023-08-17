check() {
	# Omit if building for this already configured system
	if [[ $hostonly ]] && [ -e /etc/machine-id ] && ! [ -e /var/lib/YaST2/reconfig_system ]; then
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
	inst_multiple awk chroot findmnt grep rmdir
	inst_simple "${moddir}/combustion" "/usr/bin/combustion"

	# Autodetect dasd devices on s390x to discover the config drive
	mkdir -p "${initdir}/etc/modprobe.d"
	echo "options dasd_mod dasd=autodetect" > "${initdir}/etc/modprobe.d/dasd-autodetect.conf"

	# Wait up to 10s (30s on aarch64) for the config drive
	devtimeout=10
	[ "$(uname -m)" = "aarch64" ] && devtimeout=30
	mkdir -p "${initdir}/${systemdsystemunitdir}/dev-combustion-config.device.d/"
	echo -e "[Unit]\nJobTimeoutSec=${devtimeout}" > "${initdir}/${systemdsystemunitdir}/dev-combustion-config.device.d/timeout.conf"
}
