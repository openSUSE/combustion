Combustion - configure MicroOS on the first boot
================================================

Combustion is a minimal module for dracut, which runs a user provided script on
the first boot of a system.

You can use this to create additional files, install packages, set up devices 
or even re-partition the hard disk. The configuration can be provided as a
shell script, loaded from an external storage media and is run during boot in a 
new system snapshot. On success, the system will directly boot into that new
snapshot, so that no reboot is needed.

Installation
------------

Run `make install` to install it manually. Usually combustion is packaged up
and installed during image builds already.

How to use it
-------------

The configuration files are copied from a filesystem with the LABEL
"combustion", but to be compatible and co-installable with ignition
(https://github.com/coreos/ignition), the LABEL "ignition" is used as fallback.
It expects a directory "combustion" at the root level of the filesystem and
a file "script" inside, which is executed inside a transactional-update shell.

```
 <root directory>
 ├── combustion
 │   ├── script
 │   └── ... other files
 └── ignition (optional)
     └── config.ign
```

If a QEMU fw_cfg blob with the name "opt/org.opensuse.combustion/script" is
found, it is preferred and the content of that is used as script.
Example parameter for QEMU:
-fw_cfg name=opt/org.opensuse.combustion/script,file=/var/combustion-script

You can do everything necessary for initial system configuration from this
script, including addition of ssh keys, adding users, changing passwords
or even doing partitioning changes.

Simple example
--------------

Example for formatting a USB drive and adding a config, which installs the
"vim-small" package and creates a /root/welcome file:

```bash
mkfs.ext4 /dev/sdX
e2label /dev/sdX ignition
mount /dev/sdX /mnt
mkdir -p /mnt/combustion/
cat >/mnt/combustion/script <<EOF
#!/bin/sh
# combustion: network
systemctl enable sshd.service
zypper --non-interactive install vim-small
cp welcome /root/welcome
EOF
echo "Hello User!" >/mnt/combustion/welcome
umount /mnt
```

The "# combustion: network" comment triggers networking initialization before
running the script. This is equivalent to passing "rd.neednet=1" on the kernel
cmdline and so the network configuration parameters (man dracut.cmdline) apply
here as well. If those aren't specified, it defaults to "ip=dhcp" for each
available interface.

More complex configuration example
----------------------------------

This script additionally provides visible feedback during boot, sets a password
and copies a public ssh key (which has to be in the "combustion" folder).

```bash
#!/bin/bash
# combustion: network
# Redirect output to the console
exec > >(exec tee -a /dev/tty0) 2>&1
# Set a password for root, generate the hash with "openssl passwd -6"
echo 'root:$5$.wn2BZHlEJ5R3B1C$TAHEchlU.h2tvfOpOki54NaHpGYKwdNhjaBuSpDotD7' | chpasswd -e
# Add a public ssh key and enable sshd
mkdir -pm700 /root/.ssh/
cat id_rsa_new.pub >> /root/.ssh/authorized_keys
systemctl enable sshd.service
# Install vim-small
zypper --non-interactive install vim-small
# Leave a marker
echo "Configured with combustion" > /etc/issue.d/combustion
```

How it works
------------

The ignition-dracut-grub2 package created a flag file which tells GRUB 2 that
it's the first boot of the system and so GRUB adds ignition.firstboot to the
kernel commandline.

If this option is found on the kernel cmdline, combustion.service's
ConditionKernelCommandLine is fulfilled and it'll be required by initrd.target.
This pulls in combustion-prepare.service, which runs after the config drive or
QEMU fw_cfg blob appears (see combustion.rules for details). It is read and if
the "network" flag comment is present, enables networking for later.
After /sysroot is mounted and network is up (if enabled), combustion.service
runs, which tries to activate all mountpoints in the system's /etc/fstab and
then calls transactional-update in a chroot.

In this transactional-update session the script is started and the exit code
recorded. If the script failed, transactional-update rollback is called and
combustion.service marked as failed, which causes booting to fail. Note that a
missing config drive or script is not considered a fatal error and only results
in a warning.

/sysroot is unmounted and mounted again, so that the default subvolume gets
reevaluated and directly booted into.

The ignition-firstboot-complete service in the final system runs, which deletes
the flag file. This means that combustion is not run on subsequent boots.
