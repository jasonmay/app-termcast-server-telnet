#!/usr/bin/env perl
use strict;
use warnings;
use App::Termcast::Server::Telnet;

my $app = App::Termcast::Server::Telnet->new;

$app->run;
