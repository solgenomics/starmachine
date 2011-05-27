# Starmachine

A management suite for production deployments of one or more PSGI web
apps under *nix.  Runs each app with independent libraries, using
Starman.

## Most basic setup - single app

    git clone git://github.com/solgenomics/starmachine.git
    cd starmachine;
    ln -s /path/to/myapp .;
    sudo ln -s $PWD/starmachine_init.d /etc/init.d/myapp;
    sudo /etc/init.d/myapp start

And now /etc/init.d/myapp is a well-behaved init script that starts
your app under Starman using /path/to/myapp/script/myapp.psgi with 10
workers, on port 8080, putting the logs in the starmachine dir.
