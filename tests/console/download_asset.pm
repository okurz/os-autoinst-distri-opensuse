# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Downloads ASSET_1 file to, specified by test_data, file location.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler "get_test_suite_data";
use File::Basename;

sub run {
    select_console 'root-console';
    my $file_location = get_test_suite_data()->{file_location};
    my $file_to_download = autoinst_url("/assets/other/" . basename(get_required_var("ASSET_1")));
    assert_script_run("wget " . $file_to_download . " -O  " . $file_location);
}
1;
