# SLE12 online migration tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check orphaned packages after migration
#  After the upgrade process was finished successfully, check for any
#  “orphaned packages”. Orphaned packages are packages which belong to no
#  active repository anymore.
# Maintainer: TBD
# Tags: poo#19606

use base 'installbasetest';
use strict;
use testapi;
use utils 'zypper_call';

sub run() {
    select_console 'root-console';
    # Just output packages for checking
    zypper_call('packages --orphaned');
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
