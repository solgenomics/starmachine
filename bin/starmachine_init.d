#!/usr/bin/env perl

=head1 NAME

starmachine_init.d - shared LSB init.d script for running PSGI apps with Starman

=head1 DESCRIPTION

A management suite for production deployments of one or more PSGI web
apps under *nix.  Runs each app with Starman, and can use independent
sets of libraries (e.g. C<extlib/> dirs) for each app.  Right now, the
"suite" is just a flexible init.d script.  But this might grow into a
suite.  Or it may not.

The init script itself depends only on core Perl 5.6, although of
course Starman and Server::Starter, plus your application's
dependencies, must of course be available either in the main system or
in your app's extlib for your app to run (see B<extlib> conf var
below).

=head2 Most basic setup - single app

    git clone git://github.com/solgenomics/starmachine.git
    cd starmachine;
    ln -s /path/to/myapp .;
    sudo ln -s $PWD/bin/starmachine_init.d /etc/init.d/myapp;
    sudo /etc/init.d/myapp start

And now /etc/init.d/myapp is a well-behaved init script that starts
your app under Starman using /path/to/myapp/script/myapp.psgi with 10
workers, on port 8080, putting the logs in the starmachine dir.

=cut

=head1 CONFIGURATION

Starmachine has very sensible defaults, but almost everything it does
is configurable via its configuration file.  It searches for that
configuration file in 3 places, and uses the first one it finds:

=over

=item C<STARMACHINE_CONF>

  The file name stored in the C<STARMACHINE_CONF> environment
  variable, or if that is a directory, the file
  C<$STARMACHINE_CONF/starmachine.conf> in that directory.

=item C<../starmachine.conf>

Relative to the (real) path from which this script is invoked.  This
means you can just run Starmachine out of a git checkout if you want.

=item C</etc/starmachine/starmachine.conf>

=back

=head2 Configuration format

An example configuration file for three apps
(C<ambikon_integrationserver>, C<sgn>, and C<mimosa>), looks like
this:

    root_dir = /path/to/starmachine/root
    env[CATALYST_CONFIG] = /etc/starmachine

    # conf for the ambikon front-end proxy
    ambikon_integrationserver[port] = 80
    ambikon_integrationserver[user] = www-data

    # conf for the SGN legacy app
    sgn[port] = 8201
    sgn[user] = sgn_web

    # conf for the Mimosa aligner app
    mimosa[port]       = 8202
    mimosa[user]       = mimosa
    mimosa[access_log] = /var/log/mimosa.access.log
    mimosa[error_log]  = /var/log/mimosa.error.log

=head2 Main configuration variables

=over

=item root_dir

The directory under which each application directory is assumed to
reside, unless otherwise specified with C<myapp[app_dir]>.  Defaults
to the config file's directory.

=item env

Environment variables to set for all apps.

Example:

  # set all Catalyst apps to look for their conf files in
  # /etc/starmachine
  env[CATALYST_CONFIG] = /etc/starmachine

=back

=head2 Application configuration variables

=over

=item myapp[port]

Port the app will listen on.  Default 8080.

=item myapp[user]

User that the app will run under.  Defaults to the user that runs the
init.d script.

=item myapp[group]

Group that the app will run under.  Defaults to the primary group of
the user that runs the init.d script.

=item myapp[env]

Variables to set in the app's environment.

Example:

  myapp[env][CATALYST_CONFIG] = /path/to/myapp.conf
  myapp[env][FOOBAR] = baz_1

=item myapp[workers]

Number of worker processes to use.  Default 10.

=item myapp[timeout]

todo.  Default 20.

=item myapp[preload_app]

Default 1.  If 1, preload the application in the parent process before
forking workers.

=item myapp[server_starter_args]

Default empty.  String interpolated directly into the invocation of
C<start_server> (see L<start_server>).

=item myapp[starman_args]

Default empty.  String interpolated directly into the invocation of
C<starman> (see L<starman>).

=item myapp[access_log]

Access log file.  Default C<(starmachine_root)/(app_name).access.log>.

=item myapp[error_log]

Error log file.  Default C<(starmachine_root)/(app_name).error.log>

=item myapp[app_dir]

Application main directory.  Default C<(starmachine_root)/(app_name)/>.

=item myapp[psgi_file]

Path (relative to app_dir, or absolute) of L<PSGI> file to use for
starting the app.

=item myapp[pid_file]

PID file in which to store the PID of the L<Server::Starter> parent
process.  Default C<(starmachine_root)/(app_name).pid>.

=item myapp[status_file]

L<Server::Starter> status file.  Default C<(starmachine_root)/(app_name).status>.

=item myapp[extlib]

Path to bundled dependencies (extlibs) of the app, either relative to
the B<app_dir>, or absolute.  Default: C<extlib>.

=back

=head1 COPYRIGHT

Copyright 2011 Robert Buels

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Robert Buels <rbuels@cpan.org>

=cut

use strict;
#use warnings;
use 5.8.0;
use Carp;
use FindBin '$Bin';
use File::Basename;
use File::Spec::Functions;
use IO::File;

our $VERSION = '0.1';

# lifted from ye olde Config::File module
sub read_config_file($) {
    my ($conf, $file, $fh, $line_num);
    $file = shift;
    $fh = IO::File->new($file, 'r') or
        croak "Can't read configuration in $file: $!\n";

    while (++$line_num and my $line = $fh->getline) {
        my ($orig_line, $conf_ele, $conf_data);
        chomp $line;
	$orig_line = $line;

        next if $line =~ m/^\s*#/;
        $line =~ s/(?<!\\)#.*$//;
        $line =~ s/\\#/#/g;
        next if $line =~ m/^\s*$/;
        $line =~ s{\$(\w+)}{
            exists($conf->{$1}) ? $conf->{$1} : "\$$1"
            }gsex;

	unless ($line =~ m/\s*([^\s=]+)\s*=\s*(.*?)\s*$/) {
	    warn "Line format invalid at line $line_num: '$orig_line'";
	    next;
	}

        ($conf_ele, $conf_data) = ($1, $2);
        unless ($conf_ele =~ /^[\]\[A-Za-z0-9_-]+$/) {
            warn "Invalid characters in key $conf_ele at line $line_num" .
		" - Ignoring";
            next;
        }
        $conf_ele = '$conf->{' . join("}->{", split /[][]+/, $conf_ele) . "}";
        $conf_data =~ s!([\\\'])!\\$1!g;
        eval "$conf_ele = '$conf_data'";
    }
    $fh->close;

    return $conf;
}

#############################
# use (core-only) perl to do validation and setup of environment
# variables and params, then drop into shell script for the init.d
# running

my ( $conf_file ) = grep -r, (
    $ENV{STARMACHINE_CONF},
    catfile( $ENV{STARMACHINE_CONF}, 'starmachine.conf' ),
    catfile( $FindBin::RealBin, updir(), 'starmachine.conf' ),
    '/etc/starmachine/starmachine.conf',
  );

warn "WARNING: no starmachine conf file found, using defaults for all settings.\n"
  unless $conf_file;

my $all_conf = $conf_file ? read_config_file( $conf_file ) : {};

my $starmachine_root = $all_conf->{root_dir} || dirname( $conf_file );
my $app = $ENV{STARMACHINE_APP} || basename $0;


my %conf = (
    #defaults
    port                => 8080,
    user                => $<,
    group               => ( split /\s+/, $( )[0],
    workers             => 10,
    timeout             => 20,
    preload_app         => 1,
    server_starter_args => '',
    starman_args        => '',
    access_log          => catfile( $starmachine_root, "$app.access.log" ),
    error_log           => catfile( $starmachine_root, "$app.error.log"  ),
    app_dir             => catdir( $starmachine_root, $app ),
    psgi_file           => "script/$app.psgi",
    pid_file            => catfile( $starmachine_root, "$app.pid"    ),
    status_file         => catfile( $starmachine_root, "$app.status" ),
    extlib              => 'extlib',
    env                 => {},

    % {$all_conf->{$app} || {} },
);
$conf{group} ||= $conf{user};
$conf{preload_app} = $conf{preload_app} ? '--preload-app' : '';

my $app_dir     = $conf{app_dir};
my $pid_file    = $conf{pid_file};
my $status_file = $conf{status_file};
my $psgi_file   = $conf{psgi_file};
my $extlib      = $conf{extlib};

-e $app_dir or die "app dir $app_dir does not exist, aborting.\n";
chdir $app_dir or die "cannot chdir to $app_dir, aborting.\n";

my $have_extlib = -d $extlib;

%ENV = (
    %ENV,
    %{ $all_conf->{env} || {} },
    %{       $conf{env} || {} },

    APP  => $app,
    APPDIR   => $app_dir,
    PERL5LIB => 'lib'.($have_extlib ? ":$extlib/lib/perl5" : '').":$ENV{PERL5LIB}",
    PIDFILE  => $pid_file,
    PERL_EXEC => "$^X".($have_extlib ? " -Mlocal::lib=$extlib" : ''),
    PATH  => ( $have_extlib ? "$extlib/bin:$ENV{PATH}" : $ENV{PATH} ),
    PSGI_FILE => $psgi_file,
    STARMAN => "starman --user $conf{user} --group $conf{group} --workers $conf{workers} --timeout $conf{timeout} --access-log $conf{access_log} $conf{preload_app} $conf{starman_args} $psgi_file",
    ERROR_LOG => $conf{error_log},
    ACCESS_LOG => $conf{access_log},
   );

my $start_server = eval { require IPC::Cmd; IPC::Cmd::can_run('start_server') } || `which start_server` || 'start_server';
$ENV{SERVER_STARTER} = "$start_server --pid-file=$pid_file --port=$conf{port} --status-file=$status_file $conf{server_starter_args}";

# testing hook
if( $ENV{STARMACHINE_TESTING} ) {
    require Data::Dumper;
    print Dumper( \%ENV );
    exit;
}

# now drop into sh to do the startup-scripty stuff
open( STDIN, '<&DATA' ) or die;
exec '/bin/sh', '-s', @ARGV;
__DATA__

# based loosely on site-init.sh script by Mischa Spiegelmock at
# http://wiki.catalystframework.org/wiki/deployment/perlbal-starman-psgi

. /lib/lsb/init-functions

check_running() {
    [ -s $PIDFILE ] && kill -0 $(cat $PIDFILE) >/dev/null 2>&1
}

_start() {

  $PERL_EXEC $SERVER_STARTER -- $STARMAN >>$ACCESS_LOG 2>>$ERROR_LOG &

  #echo "Waiting for $APP to start..."

  for i in 1 2 3 4 ; do
    sleep 1
    if check_running ; then
      #echo "$APP is now starting up"
      return 0
    fi
  done

  return 1
}

start() {
    log_daemon_msg "Starting web application" $APP;

    if check_running; then
        log_progress_msg "already running"
        log_end_msg 0
        exit 0
    fi

    rm -f $PIDFILE 2>/dev/null

    _start
    log_end_msg $?
    return $?
}

_stop() {
    if [ -e $PIDFILE ]; then
        kill `cat $PIDFILE`;
        for i in 1 2 3 4 5 6 7; do
            sleep 1;
            if check_running ; then
                #echo "$APP is now starting up"
                return 0
            fi
        done
        if check_running ; then
            return 1;
        fi
    fi
}
stop() {
    log_daemon_msg "Stopping web application" $APP;
    _stop;
    log_end_msg $?
    return $?
}

reload() {
    if [ -e $PIDFILE ]; then
        log_daemon_msg "Gracefully reloading web application " $APP;
        $PERL_EXEC $SERVER_STARTER --restart;
       log_end_msg $?;
    else
        log_failure_msg "No $APP running, cannot reload.";
        log_end_msg 1;
    fi
}

restart() {
    log_daemon_msg "Restarting web application" $APP;

    _stop
    _start
    log_end_msg $?
    return $?
}


case "$1" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    reload)
        reload
    ;;
    restart|force-reload)
        restart
    ;;
    *)
        echo $"Usage: $0 {start|stop|restart}"
        exit 1
esac
exit $?
