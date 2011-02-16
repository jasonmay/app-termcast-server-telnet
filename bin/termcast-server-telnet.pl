#!/usr/bin/env perl
use strict;
use warnings;

use Cwd;

use lib 'lib';
use App::Termcast::Server::Telnet;

die "Arg required (socket path)" if !@ARGV;

my $socket = Cwd::abs_path($ARGV[0]);

my $app = App::Termcast::Server::Telnet->new(service_socket => $socket);

$app->run_all();
