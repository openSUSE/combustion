MODULEDIR ?= $(DESTDIR)/usr/lib/dracut/modules.d/35combustion

all:

install:
	install -Dm0644 module-setup.sh $(MODULEDIR)/module-setup.sh
	install -Dm0644 combustion.service $(MODULEDIR)/combustion.service
	install -Dm0644 combustion-prepare.service $(MODULEDIR)/combustion-prepare.service
	install -Dm0755 combustion $(MODULEDIR)/combustion
	install -Dm0644 combustion.rules $(MODULEDIR)/combustion.rules
