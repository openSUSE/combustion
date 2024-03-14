check() {
	# Pulled in by other modules only
	return 255
}

depends() {
	echo bash systemd
}

install() {
	inst_simple "${moddir}/firstboot-detect.service" "${systemdsystemunitdir}/firstboot-detect.service"
	inst_simple "${moddir}/firstboot.target" "${systemdsystemunitdir}/firstboot.target"
	inst_simple "${moddir}/firstboot-detect" "/usr/bin/firstboot-detect"
	$SYSTEMCTL -q --root "$initdir" enable firstboot-detect.service
	inst_multiple awk grep mount

	if [ "${DRACUT_ARCH:-$(uname -m)}" = "s390x" ]; then
		# Special behaviour on s390x: On the first boot, enable all DASDs
		inst_multiple chzdev
	fi

	# Work around https://github.com/systemd/systemd/pull/28718
	mkdir -p "${initdir}/${systemdsystemunitdir}/initrd-parse-etc.service.d/"
	echo -e "[Unit]\nConflicts=emergency.target" > "${initdir}/${systemdsystemunitdir}/initrd-parse-etc.service.d/emergency.conf"
}
