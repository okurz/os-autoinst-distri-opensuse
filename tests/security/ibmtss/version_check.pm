# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Update IBM's Trusted Computing Group Software Stack (TSS) to the latest version.
#          IBM has tested x86_64, s390x and ppc64le, we only need cover aarch64
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#101088, poo#102792, tc#1769800

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    zypper_call('in ibmtss');
    my $tagert_ver = 1.6.0;
    my $current_ver = script_output("rpm -q --qf '%{version}\n' ibmtss");
    record_info("Current ibmtss package version: $current_ver");
    die 'The package version is not updated yet, please check with developer' if ($current_ver < $tagert_ver);
}

1;
