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

	# Work around https://github.com/systemd/systemd/pull/28718
	mkdir -p "${initdir}/${systemdsystemunitdir}/initrd-parse-etc.service.d/"
	echo -e "[Unit]\nConflicts=emergency.target" > "${initdir}/${systemdsystemunitdir}/initrd-parse-etc.service.d/emergency.conf"
}
