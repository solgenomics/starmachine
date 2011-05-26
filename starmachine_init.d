#!/usr/bin/env perl
use strict;
use warnings;
use FindBin '$Bin';
use File::Basename;
use File::Spec::Functions;

# use (core-only) perl to do validation and setup of environment
# variables and params, then drop into shell script for the init.d
# running

my $starmachine_root = $ENV{STARMACHINE_ROOT} || $FindBin::RealBin;
my $app = basename $0;
my $app_dir = catdir( $starmachine_root, $app );
-e $app_dir or die "app dir $app_dir does not exist, aborting.\n";
chdir $app_dir or die "cannot chdir to $app_dir, aborting.\n";

my $port = 8200;
#my $user  = 'rob';
#my $group = 'rob';
my $user  = 'www-data';
my $group = 'www-data';

my $workers = 5;
my $timeout = 20;

my $pid_file    = catfile( $starmachine_root, "$app.pid"    );
my $status_file = catfile( $starmachine_root, "$app.status" );
my $psgi_file   = "script/$app.psgi";

%ENV = (
    %ENV,
    APP  => $app,
    APPDIR   => $app_dir,
    PERL5LIB => 'lib:extlib/lib/perl5',
    PIDFILE  => $pid_file,
    PERL_EXEC => "$^X -Mlocal::lib=extlib",
    SERVER_STARTER => "extlib/bin/start_server --pid-file=$pid_file --port=$port --status-file=$status_file",
    PSGI_FILE => $psgi_file,
    STARMAN => "extlib/bin/starman --user $user --group $group --workers $workers --timeout $timeout --preload-app $psgi_file",
   );

# now drop into sh to do the startup-scripty stuff
open( STDIN, '+>&DATA' ) or die;
exec '/bin/sh', '-s', @ARGV;
__DATA__
# based on site-init.sh script by Mischa Spiegelmock at
# http://wiki.catalystframework.org/wiki/deployment/perlbal-starman-psgi

. /lib/lsb/init-functions

check_running() {
    [ -s $PIDFILE ] && kill -0 $(cat $PIDFILE) >/dev/null 2>&1
}

check_compile() {
  if ( cd $APPDIR ; $PERL_EXEC -c $PSGI_FILE ) ; then
    return 1
  else
    return 0
  fi
}

_start() {

  $PERL_EXEC $SERVER_STARTER -- $STARMAN &

  echo ""
  echo "Waiting for $APP to start..."

  for i in 1 2 3 4 ; do
    sleep 1
    if check_running ; then
      echo "$APP is now starting up"
      return 0
    fi
  done

  return 1
}

start() {
    log_daemon_msg "Starting $APP" $STARTUP_OPTS
    echo ""

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
        sleep 3;
    fi
}
stop() {
    log_daemon_msg "Stopping $APP" $STARTUP_OPTS
    echo ""
    _stop;
    log_end_msg $?
    return $?
}

reload() {
    if [ -e $PIDFILE ]; then
       log_daemon_msg "Gracefully reloading $APP" $STARTUP_OPTS;
        $PERL_EXEC $SERVER_STARTER --restart;
       log_end_msg $?;
    else
        log_failure_msg "No $APP running, cannot reload.";
        log_end_msg 1;
    fi
}

restart() {
    log_daemon_msg "Restarting $APP" $STARTUP_OPTS;

    if check_compile ; then
        log_failure_msg "Compile error; not restarting.";
        log_end_msg 1;
        exit 1;
    fi

    stop
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
