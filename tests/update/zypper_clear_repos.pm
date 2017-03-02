# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Remove published repos before updating to ensure to test only
#   assets under control of the tests.
#   This is done to prevent e.g. an upgrade to find packages from either the
#   new snapshot or the old published data which can make tests pass when
#   they should not. Then the tests fail in the subsequent snapshot because
#   the repos were updated in the meantime.
# Maintainer: Max Lin <mlin@suse.com>

use base 'consoletest';
use strict;
use testapi;
use utils;

sub run() {
    select_console 'root-console';
    my $repos_folder = '/etc/zypp/repos.d';
    assert_script_run("find $repos_folder/*.repo -type f -exec grep -q 'baseurl=http://download.opensuse.org/' {} \\; -delete");
    if (get_var('STAGING')) {
        # With FATE#320494 the local repository would be disabled after installation
        # in Staging, enable it here.
        assert_script_run("grep -rl 'baseurl=cd:///?devices' $repos_folder | xargs sed -i 's/^enabled=0/enabled=1/g'");
    }
    assert_script_run('zypper lr -d');
    save_screenshot;
}

1;
# vim: set sw=4 et:
