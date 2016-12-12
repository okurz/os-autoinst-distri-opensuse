use testapi;
use parent 'opensusebasetest';
use utils 'reload_all_needles';
use bmwqemu;

sub run {
    set_var('VERSION', '12-SP1');
    bmwqemu::save_vars;
    reload_all_needles;
    check_screen 'bootloader', 0;
}

1;
