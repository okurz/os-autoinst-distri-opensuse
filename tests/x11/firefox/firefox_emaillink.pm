# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Firefox emaillink test (Case#1436117)
# Maintainer: wnereiz <wnereiz@github>

use strict;
use base "x11test";
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    my $next_key = is_sle('<12-SP2') ? 'alt-o' : 'alt-n';

    $self->start_firefox;

    # Email link
    send_key "alt-f";
    wait_still_screen 3;
    send_key "e";
    if (is_sle('<15')) {
        assert_screen('firefox-email_link-welcome', 90);

        send_key $next_key;

        wait_still_screen 3;
        send_key $next_key;

        wait_still_screen 3;
        send_key "alt-a";
        type_string 'test@suse.com';
        send_key $next_key;

        sleep 1;
        send_key "alt-s";    #Skip

        assert_screen('firefox-email_link-settings_receiving', 90);
        send_key "alt-s";    #Server
        type_string "imap.suse.com";
        send_key "alt-n";    #Username
        type_string "test";
        if (is_sle('<12-SP2')) {
            send_key $next_key;
            wait_still_screen 3;
            send_key $next_key;
        }
        else {
            assert_and_click "evolution-option-next";
            wait_still_screen 3;
            assert_and_click "evolution-option-next";
        }

        assert_screen('firefox-email_link-settings_sending');
        send_key "alt-s";    #Server
        type_string "smtp.suse.com";
        wait_screen_change {
            send_key $next_key;
        };

        wait_still_screen 3;
        if (is_sle('<12-SP2')) {
            send_key $next_key;
        }
        else {
            assert_and_click "evolution-option-next";
        }

        wait_still_screen 3;
        send_key "alt-a";
    }
    assert_screen [qw(firefox-email_link-send firefox-launch)];
    if (match_has_tag('firefox-launch')) {
        record_soft_failure 'bsc#1079512 - evolution dumped core';
        $self->exit_firefox;
        return;
    }
    wait_screen_change {
        send_key "esc";
    };

    $self->exit_firefox;
}
1;
