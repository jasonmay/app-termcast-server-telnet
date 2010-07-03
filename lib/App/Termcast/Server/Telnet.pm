#!::usr::bin::env perl
package App::Termcast::Server::Telnet;
use Moose;
use AnyEvent::Socket;
use AnyEvent::Handle;
use App::Termcast::Handle;
use App::Termcast::Session;
use AE;
use Data::UUID::LibUUID;
use namespace::autoclean;

=head1 NAME

App::Termast::Server::Telnet - telnet interface for the termcast server

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

has telnet_port => (
    is  => 'ro',
    isa => 'Int',
    default => 23,
);

has client_handle => (
    is  => 'rw',
    isa => 'AnyEvent::Handle',
);

has client_guard => (
    is      => 'ro',
    builder => '_build_client_guard',
);

sub _build_client_guard {
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
                exit 1 if $fatal;
            },
        );

        $h->push_write(
            json => +{
                request => 'sessions',
            }
        );

        $self->client_handle($h);
    };

}

has telnet_server_guard => (
    is  => 'ro',
    builder => '_build_telnet_server_guard',
);

has stream_keymap => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { +{} },
    handles => {
        set_keymap    => 'set',
        get_keymap    => 'get',
        delete_keymap => 'delete',
    },
);

sub _build_telnet_server_guard {
    my $self = shift;

    tcp_server undef, $self->telnet_port, sub {
        my ($fh, $host, $port) = @_;
        my $h = App::Termcast::Handle->new(
            fh => $fh,
            on_read => sub {
                my $h = shift;
                $h->push_read(
                    chunk => 1, sub {
                        my ($h, $buf) = @_;
                        my $clear = "\e[2J\e[H";
                        if (ord $buf eq "255") {
                            $h->push_read(
                                chunk => 2,
                                sub { $self->handle_telnet_codes(@_) },
                            );
                        }
                        else {
                            $h->push_write("${clear}OH HAI! YOU TYPED $buf!");
                        }
                    }
                );
            },
            on_error => sub {
                my ($h, $fatal, $error) = @_;

                if ($fatal) {
                    $self->delete_telnet_session($h->handle_id);
                }
                else {
                    warn $error;
                }
            },
            handle_id => new_uuid_string()
        );

        $h->push_write(
            join(
                '',
                map { chr }
                (
                    255, 251,  1, # iac will echo
                    255, 254,  34, # iac wont linemode
                )
            )
        );
        my $session = App::Termcast::Session->with_traits(
            'App::Termcast::Server::Telnet::SessionData'
        )->new();
        $h->session($session);

        $self->set_handle($h->handle_id => $h);
    };
}

has handles => (
    is     => 'ro',
    isa    => 'HashRef',
    traits => ['Hash'],
    default => sub { +{} },
    handles => {
        set_handle    => 'set',
        delete_handle => 'delete',
        handle_ids    => 'keys',
    },
);

sub handle_telnet_codes {
    my $self = shift;
    # I don't know enough about telnet to do stuff properly here
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

