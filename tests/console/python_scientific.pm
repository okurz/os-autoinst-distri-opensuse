# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Scientific python packages
# * Test numpy
# * Test scipy
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);

sub run_python_script {
    my $script = shift;
    my $logfile = "output.txt";
    record_info($script, "Running python script: $script");
    assert_script_run("curl " . data_url("python/$script") . " -o '$script'");
    assert_script_run("chmod a+rx '$script'");
    assert_script_run("./$script 2>&1 | tee $logfile");
    if (script_run("grep 'Softfail' $logfile") == 0) {
        # bsc#1180605 is only relevant for SLE and will be hopefully solved soon by a package update
        # since there is no timeframe when this happens, we ignore this bsc for sle completely for now
        # Note: Remove 'is_sle' when available in PackageHub
        if (script_run("grep 'Softfail' $logfile | grep 'bsc#1180605'") == 0 && (is_sle)) {
            record_info("scipy-fft", "scipy-fft module not available for SLE <= 15-SP2");
        } else {
            my $failmsg = script_output("grep 'Softfail' '$logfile'");
            record_soft_failure("$failmsg");
        }
    }
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    my $scipy = is_sle('<15-sp1') ? '' : 'python3-scipy';
    zypper_call "in python3 python3-numpy $scipy";
    # Run python scripts
    run_python_script('python3-numpy-test.py');
    run_python_script('python3-scipy-test.py') unless is_sle('<15-sp1');
}

sub post_fail_hook {
    my $self = shift;
    $self->cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my $self = shift;
    $self->cleanup();
    $self->SUPER::post_run_hook;
}

sub cleanup {
    script_run('rm -f python3-numpy-test.py python3-scipy-test.py');
}

1;
