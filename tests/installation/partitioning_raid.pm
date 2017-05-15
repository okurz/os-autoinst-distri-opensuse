# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: split the partitioning monster into smaller pieces
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

# add a new primary partition
#   $type == 3 => 0xFD Linux RAID
sub addpart {
    my ($part) = @_;
    my $size = 0;

    if    ($part eq 'boot') { $size = 300; }
    elsif ($part eq 'root') { $size = 8000; }
    elsif ($part eq 'swap') { $size = 100; }
    else                    { die 'Unknown argument'; }

    assert_screen "expert-partitioner";
    send_key $cmd{addpart};
    if (!get_var('UEFI')) {    # partitioning type does not appear when GPT disk used, GPT is default for UEFI
        assert_screen "partitioning-type";
        send_key $cmd{next};
    }

    assert_screen "partition-size";

    for (1 .. 10) {
        send_key "backspace";
    }
    type_string $size . "mb";
    assert_screen "partition-size";
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key "alt-a";    # Raw Volume
    send_key $cmd{next};
    assert_screen 'partition-format';
    send_key $cmd{donotformat};
    send_key "tab";

    if ($part eq 'boot' and get_var('UEFI')) {
        send_key_until_needlematch 'partition-selected-efi-type', 'down';
    }
    else {
        send_key_until_needlematch 'partition-selected-raid-type', 'down';
    }
    send_key $cmd{finish};
}

sub addraid {
    my ($step, $chunksize) = @_;
    send_key "spc";
    for (1 .. 3) {
        for (1 .. $step) {
            send_key "ctrl-down";
        }
        send_key "spc";
    }

    # add
    send_key $cmd{add};
    wait_still_screen;
    assert_screen_change {
        send_key $cmd{next};
    };

    # chunk size selection
    if ($chunksize) {
        type_string "\t$chunksize";
    }
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key "alt-o";    # Operating System

    send_key $cmd{next};
    wait_idle 3;
}

sub setraidlevel {
    my ($level) = @_;
    my %entry = (0 => 0, 1 => 1, 5 => 5, 6 => 6, 10 => 'g');
    wait_screen_change { send_key "alt-$entry{$level}"; };

    wait_screen_change { send_key "alt-i"; };    # move to RAID name input field
    wait_screen_change { send_key "tab"; };      # skip RAID name input field
}

sub set_lvm() {
    send_key "shift-tab";
    # select LVM
    send_key "down";

    # create volume group
    send_key "alt-d";
    send_key "down";
    send_key "ret";

    assert_screen 'lvmsetupraid';
    # add all unformated lvm devices
    send_key "alt-d";

    # set volume name
    send_key "alt-v";
    type_string "root";
    assert_screen 'volumegroup-name-root';

    send_key $cmd{finish};
    wait_still_screen;

    # create logical volume
    send_key "alt-d";
    send_key "down";
    send_key "down";
    send_key "ret";

    # create normal volume with name root
    type_string "root";
    assert_screen 'volume-name-root';
    send_key $cmd{next};

    # keep default
    send_key $cmd{next};

    send_key "alt-o";    # Operating System
    send_key $cmd{next};

    # keep deafult to mount as root and btrfs
    send_key $cmd{finish};
    wait_idle 4;
}

sub run() {

    # create partitioning
    send_key $cmd{createpartsetup};
    assert_screen 'createpartsetup';

    # user defined
    send_key $cmd{custompart};
    send_key $cmd{next};
    assert_screen 'custompart';

    send_key "tab";
    send_key "down";    # select disks
    if (get_var("OFW")) {    ## no RAID /boot partition for ppc
        send_key 'alt-p';
        if (!get_var('UEFI')) {    # partitioning type does not appear when GPT disk used, GPT is default for UEFI
            assert_screen 'partitioning-type';
            send_key 'alt-n';
        }
        assert_screen 'partitioning-size';
        send_key 'ctrl-a';
        type_string "200 MB";
        send_key 'alt-n';
        assert_screen 'partition-role';
        send_key "alt-a";          # Raw Volume
        send_key 'alt-n';
        assert_screen 'partition-format';
        send_key 'alt-d';
        send_key 'alt-i';
        send_key_until_needlematch 'filesystem-prep', 'down';
        send_key 'ret';
        send_key 'alt-f';
        assert_screen 'custompart';
        send_key 'alt-s';
        send_key 'right';
        send_key 'down';           #should select first disk'
        wait_idle 5;
    }
    else {
        send_key "right";          # unfold disks
        send_key "down";           # select first disk
        wait_idle 5;
    }

    for (1 .. 4) {
        addpart('boot');
        addpart('root');
        addpart('swap');
        assert_screen 'raid-partition';

        # select next disk
        send_key "shift-tab";
        send_key "shift-tab";

        # in last step of for loop edit first vda1 and format it as EFI ESP, preparation for fate#322485
        if ($_ == 4 and get_var('UEFI')) {
            send_key 'left';     # fold the drive tree
            send_key 'right';    # select first disk
            assert_screen 'raid-partition';
            send_key 'alt-e';    # edit first partition
            assert_screen 'partition-format';
            send_key 'alt-a';           # format as FAT (first choice)
            send_key 'alt-o';           # mount point selection
            type_string '/boot/efi';    # enter mount point
            send_key $cmd{finish};
            assert_screen 'expert-partitioner';
            send_key 'shift-tab';
            send_key 'shift-tab';
            send_key 'left';            # go to top "Hard Disks" node
            send_key 'left';            # fold the drive tree again
        }

        # walk through sub-tree
        send_key "down";
    }

    # select RAID add
    send_key $cmd{addraid};
    wait_idle 4;

    setraidlevel(get_var("RAIDLEVEL"));
    send_key "down" if (!get_var('UEFI'));    # start at second partition (i.e. sda2) but not for UEFI

    if (get_var('UEFI')) {
        addraid(2, 6);
    }
    else {
        addraid(3, 6);
    }

    if (get_var('LVM')) {
        send_key $cmd{donotformat};           # 'Operating System' role to 'Raw Volume' for LVM
        send_key 'alt-u';
    }

    send_key $cmd{finish};
    wait_idle 3;

    if (!get_var('UEFI')) {
        # select RAID add
        send_key $cmd{addraid};
        wait_idle 4;
        setraidlevel(1);                      # RAID1 for /boot
        addraid(2);

        send_key "alt-s";                     # change filesystem for /boot
        for (1 .. 3) {
            send_key "down";                  # select Ext4
        }
        send_key "alt-m";
        type_string "/boot";

        send_key $cmd{finish};
        wait_idle 3;
    }

    # select RAID add
    send_key $cmd{addraid};
    wait_idle 4;
    setraidlevel(0);                          # RAID0 for swap
    addraid(1);

    # select file-system
    send_key $cmd{filesystem};
    send_key "end";                           # swap at end of list
    send_key $cmd{finish};
    wait_idle 3;

    # LVM on top of raid if needed
    if (get_var("LVM")) {
        set_lvm();
    }

    # done
    send_key $cmd{accept};

    # accept 8GB disk space with snapshots in RAID test fate#320416
    if (check_screen 'partition-small-for-snapshots', 5) {
        send_key 'alt-y';
    }
    # skip subvolumes shadowed warning
    if (check_screen 'subvolumes-shadowed', 5) {
        send_key 'alt-y';
    }
    # check overview page for Suggested partitioning
    if (get_var("LVM") and !get_var("UEFI")) {
        assert_screen 'acceptedpartitioningraidlvm';
    }
    elsif (get_var("LVM") and get_var("UEFI")) {
        assert_screen 'acceptedpartitioningraidlvmefi';
    }
    elsif (get_var("UEFI") and !get_var("LVM")) {
        assert_screen 'acceptedpartitioningraidefi';
    }
    else {
        assert_screen 'acceptedpartitioning';
    }
}


1;
# vim: set sw=4 et:
