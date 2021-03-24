# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Startup and basics of the game 0ad
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    assert_script_run 'zypper ar -p 105 https://download.opensuse.org/repositories/games/openSUSE_Tumbleweed/games.repo';
    assert_script_run 'zypper -n --gpg-auto-import-keys in 0ad';
    select_console 'x11';
    x11_start_program '0ad';
}

1;
