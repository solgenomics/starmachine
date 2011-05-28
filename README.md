# Starmachine

A management suite for production deployments of one or more PSGI web
apps under *nix.  Runs each app with independent libraries, using
Starman.  Right now, the "suite" is just a flexible init.d script.
But this might grow into a suite.  Or it may not.  We'll see.

The init script itself depends only on core Perl 5.6, although of
course Starman and Server::Starter, plus your application's
dependencies, must of course be available for your app to run.  These
can be in a `local::lib`-compatible directory, living by default at
`/path/to/myapp/extlib`.

## Most basic setup - single app

    git clone git://github.com/solgenomics/starmachine.git
    cd starmachine;
    ln -s /path/to/myapp .;
    sudo ln -s $PWD/starmachine_init.d /etc/init.d/myapp;
    sudo /etc/init.d/myapp start

And now /etc/init.d/myapp is a well-behaved init script that starts
your app under Starman using /path/to/myapp/script/myapp.psgi with 10
workers, on port 8080, putting the logs in the starmachine dir.

## Configuration

Starmachine has very sensible defaults, but almost everything it does
is configurable in a `starmachine.conf` file.  It looks like this:

    # conf for the ambikon front-end proxy
    ambikon_integrationserver[port] = 80
    ambikon_integrationserver[user] = www-data

    # conf for the SGN legacy app
    sgn[port] = 8201
    sgn[user] = sgn_web

    # conf for the Mimosa aligner app
    mimosa[port] = 8202
    mimosa[user] = mimosa
    mimosa[access_log] = /var/log/mimosa.access.log
    mimosa[error_log]  = /var/log/mimosa.error.log

### Available configuration settings

* **port**: Port the app will listen on.  Default 8080.
* **user**: User that the app will run under.  Defaults to the user that runs the init.d script.
* **group**: Group that the app will run under.  Defaults to the primary
  group of the user that runs the init.d script.
* **workers**: Number of worker processes to use.  Default 10.
* **timeout**: todo.  Default 20.
* **preload_app**: Default 1.  If 1, preload the application in the parent process before forking workers.
* **server_starter_args**: Default empty.  String interpolated directly into the invocation of `start_server` (see [start_server on the CPAN](http://search.cpan.org/perldoc?start_server)).
* **starman_args**: Default empty.  String interpolated directly into the invocation of `starman` (see [starman on the CPAN](http://search.cpan.org/perldoc?starman)).
* **access_log**: Access log file.  Default `<starmachine_root>/<app_name>.access.log`.
* **error_log**: Error log file.  Default `<starmachine_root>/<app_name>.error.log`.
* **app_dir**: Application main directory.  Default `<starmachine_root>/<app_name>/`.
* **psgi_file**: Path (relative to app_dir, or absolute) of [PSGI](http://plackperl.org) file to use for starting the app.
* **pid_file**: PID file in which to store the PID of the [Server::Starter](http://search.cpan.org/perldoc?Server::Starter) parent process.  Default `<starmachine_root>/<app_name>.pid`.
* **status_file**:  [Server::Starter](http://search.cpan.org/perldoc?Server::Starter) status file.  Default `<starmachine_root>/<app_name>.status`.
* **extlib**: Path to bundled dependencies (extlibs) of the app, either relative to the **app_dir**, or absolute.  Default: `extlib`.

