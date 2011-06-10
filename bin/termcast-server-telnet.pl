#!/usr/bin/env perl
use strict;
use warnings;

use Cwd;

use lib 'lib',
        '../app-termcast-connector/lib';
use App::Termcast::Server::Telnet;

my $app = App::Termcast::Server::Telnet->new;

$app->run();
