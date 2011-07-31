#!/usr/bin/env perl
# PODNAME: termcase-server-telnet.pl
use strict;
use warnings;

use Cwd;

use lib 'lib';
use App::Termcast::Server::Telnet;

my $app = App::Termcast::Server::Telnet->new;

$app->run();
