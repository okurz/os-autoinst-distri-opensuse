# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2
# Summary: YaST logic on Network Restart while no config changes were made
# - Launch xterm as root, stop firewalld
# - Put network in debug mode (DEBUG="yes" on /etc/sysconfig/network/config)
# - Launch yast2 lan, check network status
# - Set ip, mask, hostname and check if /etc/hosts reflects the changes
# - If not managed by network manager, do the following
#   - Check network card setup, hardware and general tabs
#   - Check network card routing tab (add 10.0.2.2 as default ipv4 route)
#   - Check hardware device name, edit card, change name to "dyn0",
# Maintainer: Zaoliang Luo <zluo@suse.com>
# Tags: fate#318787 poo#11450

use base 'y2_module_guitest';
use strict;
use warnings;
use testapi;
use y2lan_restart_common;
use y2_module_basetest 'is_network_manager_default';
use version_utils ':VERSION';

my $backend = get_required_var('BACKEND');

sub check_network_settings_tabs {
    send_key 'alt-g';    # Global options tab
    assert_screen 'yast2_lan_global_options_tab';
    send_key 'alt-s';    # Hostname/DNS tab
    assert_screen 'yast2_lan_hostname_tab';
    send_key 'alt-u';    # Routing tab
    assert_screen 'yast2_lan_routing_tab';
}

sub check_network_card_setup_tabs {
    wait_screen_change { send_key 'home' };
    send_key_until_needlematch 'yast2_lan_select_eth_card', 'down';
    send_key 'alt-i';
    assert_screen 'yast2_lan_network_card_setup';
    send_key 'alt-w';
    assert_screen 'yast2_lan_hardware_tab';
    send_key 'alt-g';
    assert_screen 'yast2_lan_general_tab';
    send_key 'alt-n';
}

sub check_default_gateway {
    send_key 'alt-u';    # Routing tab
    assert_screen 'yast2_lan_routing_tab';
    send_key 'alt-f';    # select Default IPv4 Gateway
    type_string '10.0.2.2';
    save_screenshot;
    send_key 'alt-g';    # Global options tab
    assert_screen 'yast2_lan_global_options_tab';
    send_key 'alt-u';    # Routing tab
    assert_screen 'yast2_lan_routing_tab';
    send_key 'alt-f';
    send_key 'backspace';    # Delete selected IP
}

sub change_hw_device_name {
    my $dev_name = shift;

    send_key 'alt-i';    # Edit NIC
    assert_screen 'yast2_lan_network_card_setup';
    if (is_sle('15-SP2+')) {
        send_key 'alt-g';    # Starting with SLE15 SP2, "Device name" field is shown in General tab
    } else {
        send_key 'alt-w';    # Hardware tab
        assert_screen 'yast2_lan_hardware_tab';
    }
    send_key 'alt-e';    # Change device name
    assert_screen 'yast2_lan_device_name';
    send_key 'tab' for (1 .. 2);
    type_string $dev_name;
    wait_screen_change { send_key 'alt-m' };    # Udev rule based on MAC
    save_screenshot;
    send_key $cmd{ok};
    send_key $cmd{next};
}

sub run {
    initialize_y2lan;
    verify_network_configuration;    # check simple access to Overview tab
    my $service_status_after_conf = (is_sle('<=15')) ? 'no_restart_or_reload' : 'reload';
    if ($backend eq "svirt") {
        verify_network_configuration(\&check_network_settings_tabs, $service_status_after_conf);
    }
    else {
        verify_network_configuration(\&check_network_settings_tabs);
    }
    unless (is_network_manager_default) {
        # Run detailed check only if explicitly configured in the test suite
        check_etc_hosts_update() if get_var('VALIDATE_ETC_HOSTS');
        record_info "check_network_card_setup_tabs";
        verify_network_configuration(\&check_network_card_setup_tabs, $service_status_after_conf);
        record_info "check_default_gateway";
        verify_network_configuration(\&check_default_gateway);
        record_info "change_hw_device_name";
        $service_status_after_conf = (is_sle('<=15-SP1')) ? 'restart' : 'reload';
        verify_network_configuration(\&change_hw_device_name, $service_status_after_conf, 'dyn0');
    }
    enter_cmd "killall xterm";
}

sub test_flags {
    return {always_rollback => 1};
}

1;
