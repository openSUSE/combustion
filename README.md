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
All-uppercase labels are accepted as well. Alternatively, if a KIWI selfinstall
.iso is used for deployment (LABEL "INSTALL"), this is used as a fallback.

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

The `# combustion: network` comment triggers networking initialization before
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

Perform modifications in the initrd environment
-----------------------------------------------

Using the `# combustion: prepare` marker, the initrd environment can be modified
for instance to perform tasks before `/sysroot` is mounted or to write
NetworkManager connection configuration into
`/etc/NetworkManager/system-connections/`. If the marker is present, the script
is invoked with `--prepare` as parameter from `combustion-prepare.service`, in
addition to the main invocation inside the transaction later.
Example:

```bash
#!/bin/bash
# combustion: network prepare
set -euxo pipefail

nm_config() {
    umask 077 # Required for NM config
    mkdir -p /etc/NetworkManager/system-connections/
    cat >/etc/NetworkManager/system-connections/static.nmconnection <<-EOF
    [connection]
    id=static
    type=ethernet
    autoconnect=true

    [ipv4]
    method=manual
    dns=192.168.100.1
    address1=192.168.100.42/24,192.168.100.1
EOF
}

if [ "${1-}" = "--prepare" ]; then
    nm_config # Configure NM in the initrd
    exit 0
fi

# Redirect output to the console
exec > >(exec tee -a /dev/tty0) 2>&1

nm_config # Configure NM in the system
curl example.com
# Leave a marker
echo "Configured with combustion" > /etc/issue.d/combustion
```

How it works
------------

### Firstboot detection

Combustion ships a `firstboot` dracut module which introduces `firstboot.target`
as well as a `firstboot-detect.service`. This service mounts `/sysroot/etc`
early in the initrd (in a private namespace, to not trigger `.mount` units and
dependencies out of order). It then checks for the following conditions:

* `combustion.firstboot` or `ignition.firstboot` are present on the kernel
cmdline
* `/etc/machine-id` does not exist in `/sysroot`. Note: Unlike systemd's
`ConditionFirstBoot`, this is not triggered by "uninitialized" in the
machine-id file or influcenced by `systemd.firstboot=` on the kernel cmdline.

If one of them applies, it enables and starts `firstboot.target`. It's
important that all units started by `firstboot.target` are effectively
ordered after `firstboot-detect.service` to prevent loops. Add some Before=
to `firstboot-detect.service` if necessary.

If any of the firstboot configuration mechanisms (combustion, ignition)
find a user specified config, they delete `/var/lib/YaST2/reconfig_system`.
The result is that if (and only if) no configuration for those was provided,
the file still exists in the real system and triggers interactive setup
(jeos-firstboot, YaST Firstboot) if present.

The final system eventually reaches `first-boot-complete.target` and after that
`systemd-machine-id-commit.service`, which commits `/etc/machine-id` to disk and
thus `firstboot-detect.service` no longer triggers `firstboot.target` on
subsequent boots.

### Combustion

The `combustion` dracut module is included by default, but omitted if dracut is
run on an already configured system in `hostonly` mode.

`firstboot.target` pulls in `combustion.service` and
`combustion-prepare.service`. The latter runs after the config drive or
QEMU fw_cfg blob appears (see `combustion.rules` for details). The combustion
configuration is copied from the config source into `/dev/shm/combustion/config`
(this is accessible in `transactional-update shell` later). If the script
contains the `prepare` flag, it's executed now with the `--prepare` option. If
the `network` flag is present, networking is enabled in the initrd. After
`/sysroot` is mounted and network is up (if enabled), `combustion.service` runs,
which tries to activate all mountpoints in the system's /etc/fstab and then
calls transactional-update in a chroot.

In this transactional-update session the script is started and the exit code
recorded. If the script failed, transactional-update rollback is called and
combustion.service marked as failed, which causes booting to fail. Note that a
missing config drive or script is not considered a fatal error and only results
in a warning.

/sysroot is unmounted and mounted again, so that the default subvolume gets
reevaluated and directly booted into.

Now, `initrd-parse-etc.service` can evaluate the final `/sysroot/etc/fstab` and
create the matching `sysroot-FOO.mount` units which are started before switching
into the root filesystem.
