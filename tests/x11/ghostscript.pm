# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add ghostscript test
#    This test downloads a script that converts all the .ps images in
#    the examples to .pdf files. If one (or more) were not converted
#    then a file called failed is created and the test fails. Also it
#    will display one of the generated PDFs to see if gv works.
# Maintainer: Dario Abatianni <dabatianni@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run() {
    select_console 'x11';
    ensure_installed 'ghostscript ghostscript-x11 gv';
    x11_start_program 'xterm';

    my $gs_script = "ghostscript_ps2pdf.sh";
    my $gs_log    = "ghostscript.log";
    my $gs_failed = "/tmp/ghostscript_failed";
    my $reference = "alphabet.pdf";

    # download ghostscript converter script and test if download succeeded
    assert_script_run "wget " . data_url("ghostscript/$gs_script");
    assert_script_run "test -f $gs_script";
    assert_script_run "test -s $gs_script";

    # convert example *.ps files to *.pdf
    assert_script_run "sh ./$gs_script";

    # show the resulting logfile onthe screen for reference and upload logs
    script_run "cat $gs_log";
    upload_logs $gs_log;

    # check if there was an error during the pdf generation
    assert_script_run "test ! -f $gs_failed";

    # display one reference pdf on screen and check if it looks correct
    # skip this when there is no gv installed. Special case for gv which is
    # not available on all flavors
    if (!script_output 'rpm -q --quiet gv') {
        script_run "gv $reference", 0;
        assert_screen "ghostview_alphabet";

        # close gv
        send_key "alt-f4";
        wait_still_screen;
    }

    # cleanup temporary files
    script_run "rm -f $gs_log $reference $gs_script";

    # close xterm
    send_key "alt-f4";
}

1;

