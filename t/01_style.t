#!/usr/bin/perl
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Test::Most;

my $out = qx{git grep -I -l 'Copyright \\((C)\\|(c)\\|©\\)' '!:*.ps'};
ok $? != 0 && $out eq '', 'No redundant copyright character' or diag $out;
ok system(qq{git grep -I -l 'This program is free software.*if not, see <http://www.gnu.org/licenses/' ':!t/01_style.t'}) != 0, 'No verbatim GPL licenses in source files';
ok system(qq{git grep -I -l '[#/ ]*SPDX-License-Identifier ' ':!t/01_style.t'}) != 0, 'SPDX-License-Identifier correctly terminated';
done_testing;
