# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Startup and basics of the game wesnoth using Inline::Python
# Maintainer: Oliver Kurz <okurz@suse.de>

use Inline Python => <<'END';
perl.use('testapi')
testapi = perl.testapi
from testapi import select_console, send_key
perl.use('x11test')
x11test = perl.x11test
perl.eval()

def run(self):
    select_console('x11')
    ensure_installed('wesnoth')
    self.x11_start_program('wesnoth')
    send_key('alt-f4')
 
END