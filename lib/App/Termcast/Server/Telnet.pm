#!::usr::bin::env perl
package App::Termast::Server::Telnet;
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

has handle => (
    is  => 'ro',
    isa => 'AnyEvent::Handle',
);

has server_guard => (
    is  => 'rw',
    lazy_build => 1,
);

sub _build_server_guard {
    my $self = shift;

tcp_connect 'localhost', 9092, sub {
    my ($fh) = @_
        or die "localhost connect failed: $!";

    $h = AnyEvent::Handle->new(
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
                            warn "something";
                        }
                    }
                    elsif ($data->{response} eq 'stream') {
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

    $self->handle($h);
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

