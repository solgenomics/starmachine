#!/usr/bin/env perl
use inc::Module::Install;

name 'Starmachine';
all_from 'bin/starmachine_init.d';
readme_from;

install_script glob('bin/*');
auto_install;
WriteAll;
