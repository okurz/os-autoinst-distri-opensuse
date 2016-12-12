use testapi;
use parent 'opensusebasetest';
use utils 'reload_all_needles';
use bmwqemu;

sub run {
    # TODO switch version
    set_var('VERSION', '12-SP2');
    bmwqemu::save_vars;
    reload_all_needles;
}

1;
