use testapi;
use parent 'opensusebasetest';

sub run {
    check_screen 'bootloader', 0;
}

1;
