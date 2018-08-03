# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: svirt bootloader
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_jeos is_caasp is_installcheck is_rescuesystem is_sle);
use registration 'registration_bootloader_cmdline';
use File::Basename;

sub copy_image {
    my ($file, $dir) = @_;
    my $basename = basename($file);
    my $path     = `find $dir -name $basename | head -n1 | tr -d '\n'`;
    diag("Path found: $path");
    type_string("# Copying image $basename...\n");
    return $path;
}

sub run {
    my $arch       = get_var('ARCH');
    my $vmm_family = get_required_var('VIRSH_VMM_FAMILY');
    my $vmm_type   = get_required_var('VIRSH_VMM_TYPE');

    my $svirt = select_console('svirt');
    my $name  = $svirt->name;
    my $repo;

    # Workaround before fix in svirt (https://github.com/os-autoinst/os-autoinst/pull/901) is deployed
    my $n = get_var('NUMDISKS', 1);
    set_var('NUMDISKS', defined get_var('RAIDLEVEL') ? 4 : $n);

    my $xenconsole = "hvc0";
    if (!get_var('SP2ORLATER')) {
        $xenconsole = "xvc0";
    }

    set_var('BOOTFROM', 'c') if get_var('BOOT_HDD_IMAGE');
    if (check_var('BOOTFROM', 'c')) {
        $svirt->change_domain_element(os => boot => {dev => 'hd'});
    }
    elsif (check_var('BOOTFROM', 'd')) {
        $svirt->change_domain_element(os => boot => {dev => 'cdrom'});
    }
    else {
        $svirt->change_domain_element(os => boot => {dev => 'hd'});
        $svirt->change_domain_element(os => boot => {dev => 'cdrom'}) if get_var('ISO');
    }

    # Unless os-autoinst PR#956 is deployed we have to remove 'on_reboot' first
    $svirt->change_domain_element(on_reboot => undef);
    $svirt->change_domain_element(on_reboot => 'destroy');

    my $dev_id = 'a';
    my $isodir = '/var/lib/openqa/share/factory/iso /var/lib/openqa/share/factory/iso/fixed';
    # In netinstall we don't have ISO media, for the rest we attach it, if it's defined
    if (my $isofile = get_var('ISO')) {
        my $isopath = copy_image($isofile, $isodir);
        $svirt->add_disk(
            {
                cdrom  => 1,
                file   => ($vmm_family eq 'vmware') ? basename($isopath) : $isopath,
                dev_id => $dev_id
            });
        $dev_id = chr((ord $dev_id) + 1);    # return next letter in alphabet
    }
    # Add addon media (if present at all)
    foreach my $n (1 .. 9) {
        if (my $addon_isofile = get_var("ISO_" . $n)) {
            my $addon_isopath = copy_image($addon_isofile, $isodir);
            $svirt->add_disk(
                {
                    cdrom  => 1,
                    file   => ($vmm_family eq 'vmware') ? basename($addon_isopath) : $addon_isopath,
                    dev_id => $dev_id
                });
            $dev_id = chr((ord $dev_id) + 1);    # return next letter in alphabet
        }
    }

    my $hdddir = '/var/lib/openqa/share/factory/hdd /var/lib/openqa/share/factory/hdd/fixed';
    my $size_i = get_var('HDDSIZEGB', '10');
    foreach my $n (1 .. get_var('NUMDISKS')) {
        if (my $hdd = get_var('HDD_' . $n)) {
            my $hddpath = copy_image($hdd, $hdddir);
            $svirt->add_disk(
                {
                    backingfile => 1,
                    dev_id      => $dev_id,
                    file        => ($vmm_family eq 'vmware') ? basename($hddpath) : $hddpath
                });
        }
        else {
            $svirt->add_disk(
                {
                    create => 1,
                    dev_id => $dev_id,
                    size   => $size_i . 'G'
                });
        }
        $dev_id = chr((ord $dev_id) + 1);    # return next letter in alphabet
    }

    # We need to use 'tablet' as a pointer device, i.e. a device
    # with absolute axis. That needs to be explicitely configured
    # on KVM and Xen HVM only. VMware and Xen PV add pointer
    # device with absolute axis by default.
    if (($vmm_family eq 'kvm') or ($vmm_family eq 'xen' and $vmm_type eq 'hvm')) {
        $svirt->add_input({type => 'tablet',   bus => 'usb'});
        $svirt->add_input({type => 'keyboard', bus => 'ps2'});
    }

    my $console_target_type;
    if ($vmm_family eq 'xen' && $vmm_type eq 'linux') {
        $console_target_type = 'xen';
    }
    else {
        $console_target_type = 'serial';
    }
    # esx driver in libvirt does not support `virsh console' command. We need
    # to export it on our own via TCP.
    my $pty_dev_type;
    if ($vmm_family eq 'vmware') {
        $pty_dev_type = 'tcp';
    }
    else {
        $pty_dev_type = 'pty';
    }
    my $protocol_type;
    my $source = 0;
    if ($vmm_family eq 'vmware') {
        $protocol_type = 'raw';
        $source        = 1;
    }
    $svirt->add_pty(
        {
            pty_dev       => 'console',
            pty_dev_type  => $pty_dev_type,
            target_type   => $console_target_type,
            target_port   => '0',
            protocol_type => $protocol_type,
            source        => $source
        });
    if (!($vmm_family eq 'xen' && $vmm_type eq 'linux')) {
        $svirt->add_pty(
            {
                pty_dev       => 'serial',
                pty_dev_type  => $pty_dev_type,
                target_port   => '0',
                protocol_type => $protocol_type,
                source        => $source
            });
    }

    $svirt->add_vnc({port => get_var('VIRSH_INSTANCE', 1) + 5900});

    my %ifacecfg = ();

    # VMs should be specified with known-to-work network interface.
    # Xen PV and Hyper-V use streams.
    my $iface_model;
    if ($vmm_family eq 'kvm') {
        $iface_model = 'virtio';
    }
    elsif ($vmm_family eq 'xen' && $vmm_type eq 'hvm') {
        $iface_model = 'netfront';
    }
    elsif ($vmm_family eq 'vmware') {
        $iface_model = 'e1000';
    }

    if ($iface_model) {
        $ifacecfg{model} = {type => $iface_model};
    }

    if ($vmm_family eq 'vmware') {
        # `virsh iface-list' won't produce correct bridge name for VMware.
        # It should be provided by the worker or relied upon the default.
        $ifacecfg{type} = 'bridge';
        $ifacecfg{source} = {bridge => get_var('VMWARE_BRIDGE', 'VM Network')};
    }
    elsif ($vmm_family eq 'kvm') {
        $ifacecfg{type} = 'user';
        # This is the default MAC address for user mode networking; same in qemu backend
        $ifacecfg{mac} = {address => '52:54:00:12:34:56'};
    }
    else {
        # We can use bridge or network as a base for network interface. Network named 'default'
        # happens to be omnipresent on workstations, bridges (br0, ...) on servers. If both 'default'
        # network and bridge are defined and active, bridge should be prefered as 'default' network
        # does not work.
        if (my $bridges = $svirt->get_cmd_output("virsh iface-list --all | grep -w active | awk '{ print \$1 }' | tail -n1 | tr -d '\\n'")) {
            $ifacecfg{type} = 'bridge';
            $ifacecfg{source} = {bridge => $bridges};
        }
        elsif (my $networks = $svirt->get_cmd_output("virsh net-list --all | grep -w active | awk '{ print \$1 }' | tail -n1 | tr -d '\\n'")) {
            $ifacecfg{type} = 'network';
            $ifacecfg{source} = {network => $networks};
        }
    }

    $svirt->add_interface(\%ifacecfg);

    $svirt->define_and_start;

    # This sets kernel argument so needle-matching works on Xen PV. It's being
    # done via host's PTY device because we don't see anything unless kernel
    # sets framebuffer (this is a GRUB2's limitation bsc#961638).
    if ($vmm_family eq 'xen' and $vmm_type eq 'linux') {
        $svirt->suspend;
        my $cmdline = '';
        $cmdline .= 'textmode=1 ' if check_var('VIDEOMODE', 'text');
        $cmdline .= 'rescue=1 ' if is_installcheck || is_rescuesystem;    # rescue mode
        $cmdline .= get_var('EXTRABOOTPARAMS') . ' ' if get_var('EXTRABOOTPARAMS');
        $cmdline .= registration_bootloader_cmdline . ' ' if check_var('SCC_REGISTER', 'installation');
        type_string "export pty=`virsh dumpxml $name | grep \"console type=\" | sed \"s/'/ /g\" | awk '{ print \$5 }'`\n";
        type_string "echo \$pty\n";
        $svirt->resume;
        wait_serial("Press enter to boot the selected OS", 10) || die "Can't get to GRUB";
        # Do not boot OS from disk, select installation medium
        if (!get_var('BOOT_HDD_IMAGE') && get_var('ISO') && get_var('HDD_1') && !is_jeos && !is_caasp) {
            type_string "echo -en '\\033[B' > \$pty\n";                   # key down
        }
        type_string "echo e > \$pty\n";                                   # edit

        if (is_jeos or is_caasp) {
            for (1 .. 4) { type_string "echo -en '\\033[B' > \$pty\n"; }    # four-times key down
        }
        else {
            $cmdline .= 'linemode=0 ';                                      # workaround for bsc#1066919
            for (1 .. 2) { type_string "echo -en '\\033[B' > \$pty\n"; }    # four-times key down
        }
        type_string "echo -en '\\033[K' > \$pty\n";                         # end of line
        type_string "echo -en ' $cmdline' > \$pty\n";
        if (is_sle('12-SP2+') or is_caasp) {
            type_string "echo -en ' xen-fbfront.video=32,1024,768 xen-kbdfront.ptr_size=1024,768 ' > \$pty\n";    # set kernel framebuffer
            type_string "echo -en ' console=hvc console=tty ' > \$pty\n";                                         # set consoles
        }
        else {
            type_string "echo -en ' xenfb.video=4,1024,768' > \$pty\n";                                           # set kernel framebuffer
            type_string "echo -en ' console=xvc console=tty' > \$pty\n";                                          # set consoles
        }

        type_string "echo -en '\\x18' > \$pty\n";                                                                 # send Ctrl-x to boot guest kernel
        save_screenshot;
    }

    # If we connect to 'sut' VNC display "too early" the VNC server won't be
    # ready we will be left with a blank screen.
    sleep 2 if $vmm_family eq 'vmware';

    # connects to a guest VNC session
    select_console('sut', await_console => 0);
}

1;
