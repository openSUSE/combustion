FB_MODULEDIR ?= $(DESTDIR)/usr/lib/dracut/modules.d/30firstboot
MODULEDIR ?= $(DESTDIR)/usr/lib/dracut/modules.d/35combustion

all:

install-30firstboot:
	install -Dm0644 30firstboot/module-setup.sh $(FB_MODULEDIR)/module-setup.sh
	install -Dm0644 30firstboot/firstboot.target $(FB_MODULEDIR)/firstboot.target
	install -Dm0755 30firstboot/firstboot-detect $(FB_MODULEDIR)/firstboot-detect
	install -Dm0644 30firstboot/firstboot-detect.service $(FB_MODULEDIR)/firstboot-detect.service

install: install-30firstboot
	install -Dm0644 module-setup.sh $(MODULEDIR)/module-setup.sh
	install -Dm0644 combustion.service $(MODULEDIR)/combustion.service
	install -Dm0644 combustion-prepare.service $(MODULEDIR)/combustion-prepare.service
	install -Dm0755 combustion $(MODULEDIR)/combustion
	install -Dm0644 combustion.rules $(MODULEDIR)/combustion.rules

.PHONY: all install install-30firstboot
