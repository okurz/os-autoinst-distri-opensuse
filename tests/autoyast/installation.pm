# Copyright (C) 2015 SUSE Linux GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Autoyast installation
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use base 'basetest';
use testapi;
use utils;

my $confirmed_licenses = 0;
my $stage;

sub accept_license {
    send_key $cmd{accept};
    $confirmed_licenses++;
    # Prevent from matching previous license
    assert_screen_change {
        send_key $cmd{next};
    };
}

sub save_logs_and_continue {
    my ($name) = @_;
    $name //= $stage;
    # save logs and continue
    select_console 'install-shell';

    # the network may be down with keep_install_network=false
    # use static ip in that case
    type_string "
      save_y2logs /tmp/y2logs-$name.tar.bz2
      if ! ping -c 1 10.0.2.2 ; then
        ip addr add 10.0.2.200/24 dev eth0
        ip link set eth0 up
        route add default gw 10.0.2.2
      fi
    ";
    upload_logs "/tmp/y2logs-$name.tar.bz2";
    save_screenshot;
    clear_console;
    select_console 'installation';
}

sub save_logs_in_linuxrc {
    my $name = shift;
    select_console 'install-shell2', tags => 'install-shell';

    # save_y2logs is not present
    assert_script_run "tar czf /tmp/logs-$name.tar.bz2 /var/log";
    upload_logs "/tmp/logs-$name.tar.bz2";
}

sub handle_expected_errors {
    my ($stage, %args) = @_;
    my $i = $args{iteration};
    record_info('Expected error', 'Iteration = ' . $i);
    send_key "alt-s";    #stop
    save_logs_and_continue("stage1_error$i");
    $i++;
    send_key "tab";      #continue
    send_key "ret";
    wait_idle(5);
}

sub run {
    my @needles = ("bios-boot", "autoyast-error", "reboot-after-installation", "linuxrc-install-fail");
    push @needles, "autoyast-confirm"        if get_var("AUTOYAST_CONFIRM");
    push @needles, "autoyast-postpartscript" if get_var("USRSCR_DIALOG");
    if (get_var("AUTOYAST_LICENSE")) {
        push @needles, (get_var('BETA') ? 'inst-betawarning' : 'autoyast-license');
    }

    my $postpartscript = 0;
    my $confirmed      = 0;

    my $maxtime    = 2000;
    my $i          = 1;
    my $num_errors = 0;
    $stage = 'stage1';
    mouse_hide(1);
    do {
        assert_screen \@needles, $maxtime;
        #repeat until timeout or login screen
        if (match_has_tag('autoyast-error')) {
            handle_expected_errors('stage1', iteration => $i);
            $num_errors++;
        }
        elsif (match_has_tag('linuxrc-install-fail')) {
            save_logs_in_linuxrc("stage1_error$i");
            die "installation ends in linuxrc";
        }
        elsif (match_has_tag('autoyast-confirm')) {
            # select network (second entry)
            send_key "ret";

            assert_screen("startinstall", 20);

            send_key "tab";
            send_key "ret";
            wait_idle(5);
            @needles = grep { $_ ne 'autoyast-confirm' } @needles;
            $confirmed = 1;
        }
        elsif (match_has_tag('autoyast-license')) {
            accept_license;
        }
        elsif (match_has_tag('inst-betawarning')) {
            send_key $cmd{ok};
            assert_screen 'autoyast-license';
            accept_license;
        }
        elsif (match_has_tag('autoyast-postpartscript')) {
            @needles = grep { $_ ne 'autoyast-postpartscript' } @needles;
            $postpartscript = 1;
        }
    } until (match_has_tag('reboot-after-installation') || match_has_tag('bios-boot'));

    if (get_var("USRSCR_DIALOG")) {
        die "usrscr dialog" if !$postpartscript;
    }

    if (get_var("AUTOYAST_CONFIRM")) {
        die "autoyast_confirm" if !$confirmed;
    }

    if (get_var("AUTOYAST_LICENSE")) {
        if ($confirmed_licenses == 0 || $confirmed_licenses != get_var("AUTOYAST_LICENSE", 0)) {
            die "autoyast_license";
        }
    }

    # CaaSP does not have second stage
    return if is_casp;

    $stage = 'stage2';
    mouse_hide(1);
    $maxtime = 1000;
    do {
        assert_screen qw(reboot-after-installation autoyast-expected-error), $maxtime;
        if (match_has_tag('autoyast-error')) {
            handle_expected_errors('stage2', iteration => $i);
            $num_errors++;
        }
    } until match_has_tag 'reboot-after-installation';

    my $expect_errors = get_var("AUTOYAST_EXPECT_ERRORS") // 0;
    die "exceeded expected autoyast errors" if $num_errors != $expect_errors;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    save_logs_and_continue;
}

1;

# vim: set sw=4 et:
