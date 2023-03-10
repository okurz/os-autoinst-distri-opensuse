use base 'consoletest';
use strict;
use warnings;
use testapi;

sub run {
    select_console('root-console');
    enter_cmd 'echo c > /proc/sysrq-trigger';
    wait_serial 'CONTINUE', 3600;
}

1;
