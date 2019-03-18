# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: console test pre setup, performing actions required to run tests
# which are supposed to be reverted e.g. stoping and disabling packagekit and so on
# Permanent changes are now executed in system_prepare module
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use testapi;
use utils;
use Utils::Backends qw(has_ttys use_ssh_serial_console);
use strict;
use warnings;
use version_utils 'is_sle';

sub disable_bash_mail_notification {
    assert_script_run "unset MAILCHECK >> ~/.bashrc";
    assert_script_run "unset MAILCHECK";
}

sub run {
    my $self = shift;
    # let's see how it looks at the beginning
    save_screenshot;
    check_var("BACKEND", "ipmi") ? use_ssh_serial_console : select_console 'root-console';
    # Stop serial-getty on serial console to avoid serial output pollution with login prompt
    disable_serial_getty;
    # Prevent mail notification messages to show up in shell and interfere with running console tests
    disable_bash_mail_notification;
    check_console_font if has_ttys();

    script_run 'echo "set -o pipefail" >> /etc/bash.bashrc.local';
    script_run '. /etc/bash.bashrc.local';

    # Stop packagekit
    if (is_sle('<12-sp3')) {
        systemctl 'mask packagekit';
        systemctl 'stop packagekit';
    } else {
        systemctl 'mask --now packagekit';
    }

    $self->clear_and_verify_console;
    select_console 'user-console';
    # Shell enviromental variable MAILCHECK has to be updated for both users
    disable_bash_mail_notification;
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
