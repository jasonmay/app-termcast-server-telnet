#!/usr/bin/env perl
use strict;
use warnings;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AE;

my $h;
my $tc = tcp_connect 'localhost', 9092, sub {
    my ($fh) = @_
        or die "localhost connect failed: $!";

    $h = AnyEvent::Handle->new(
        fh => $fh,
        on_read => sub {
            my ($h, $host, $port) = @_;
            $h->push_read(
                json => sub {
                    my ($h, $data) = @_;
                    if ($data->{response} eq 'sessions') {
                        my %sessions = %{ $data->{sessions} };
                        if (keys %sessions) {
                            warn "something";
                        }
                    }
                    elsif ($daa->{response} eq 'stream') {
                        warn $data->{stream};
                    }
                }
            );
        },
        on_error => sub {
            my ($h, $fatal, $error) = @_;
            warn $error;
            die if $fatal;
        },
    );

    $h->push_write(
        json => +{
            request => 'sessions',
        }
    );
    warn "get to here at all?";
};



my $t = AE::timer 0, 1, sub {
    $h->push_write(
        json => +{
            request => 'sessions',
        }
    ) if $h;
};

AE::cv->recv;
