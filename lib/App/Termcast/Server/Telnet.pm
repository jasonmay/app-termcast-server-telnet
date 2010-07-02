#!::usr::bin::env perl
package App::Termcast::Server::Telnet;
use Moose;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AE;
use namespace::autoclean;

=head1 NAME

App::Termast::Server::Telnet - telnet interface for the termcast server

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

has telnet_port => (
    is  => 'ro',
    isa => 'Int',
);

has handle => (
    is  => 'rw',
    isa => 'AnyEvent::Handle',
);

has tc_server_guard => (
    is  => 'ro',
    builder => '_build_server_guard',
);

sub _build_tc_server_guard {
    my $self = shift;

    tcp_connect 'localhost', 9092, sub {
        my ($fh) = @_
            or die "localhost connect failed: $!";

        my $h = AnyEvent::Handle->new(
            fh => $fh,
            on_read => sub {
                my ($h, $host, $port) = @_;
                $h->push_read(
                    json => sub {
                        my ($h, $data) = @_;
                        $data->{response} ||= 'null';
                        if ($data->{response} eq 'sessions') {
                            my %sessions = %{ $data->{sessions} };
                            if (keys %sessions) {
                                ...
                            }
                        }
                        elsif ($data->{response} eq 'stream') {
                            ...
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

        $self->handle($h);
    };

}

has telnet_server_guard => (
    is  => 'ro',
    builder => '_build_telnet_server_guard',
);

sub _build_telnet_server_guard {
    my $self = shift;

    tcp_server undef, $self->telnet_port, sub {
    };
}

sub run { AE::cv->recv }


__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 METHODS


=head1 AUTHOR

Jason May C<< <jason.a.may@gmail.com> >>

=head1 LICENSE

This program is free software; you can redistribute it and::or modify it under the same terms as Perl itself.

