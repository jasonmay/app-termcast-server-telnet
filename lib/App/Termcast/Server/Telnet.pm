#!::usr::bin::env perl
package App::Termcast::Server::Telnet;
use Moose;
use AnyEvent::Socket;
use AnyEvent::Handle;
use App::Termcast::Handle;
use App::Termcast::Session;
use AE;
use YAML;
use Data::UUID::LibUUID;
use namespace::autoclean;

use constant CLEAR => "\e[2J\e[H";

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
                        if ($data->{notice}) {
                            $self->handle_server_notice($data);
                        }
                        elsif ($data->{response}) {
                            $self->handle_server_response($data);
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

has stream_data => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { +{} },
    handles => {
        set_stream         => 'set',
        stream_ids         => 'keys',
        get_stream         => 'get',
        delete_stream      => 'delete',
        clear_stream_data  => 'clear',
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
                        if (ord $buf eq "255") {
                            $h->push_read(
                                chunk => 2,
                                sub { $self->handle_telnet_codes(@_) },
                            );
                        }
                        else {
                            $self->send_connection_list($h);
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
                (
                    map { chr }
                    (
                        255, 251,  1, # iac will echo
                        255, 251,  3, # iac will suppres go_ahead
                        255, 254, 34, # iac wont linemode
                    )
                )
            )
        );

        my $session = App::Termcast::Session->with_traits(
            'App::Termcast::Server::Telnet::SessionData'
        )->new();
        $h->session($session);

        $self->set_handle($h->handle_id => $h);
        $self->send_connection_list($h);
    };
}

has handles => (
    is      => 'ro',
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { +{} },
    handles => {
        set_handle    => 'set',
        delete_handle => 'delete',
        handle_ids    => 'keys',
        handle_list   => 'values',
    },
);

sub handle_telnet_codes {
    my $self             = shift;
    my $handle           = shift;
    my ($verb, $feature) = split '', shift;
    # I don't know enough about telnet to do stuff properly here
}

sub handle_server_notice {
    my $self = shift;
    my $data = shift;

    if ($data->{notice} eq 'connect') {
        $self->set_stream(
            $data->{connection}{session_id} => $data->{connection},
        );
    }
    elsif ($data->{notice} eq 'disconnect') {
        $self->delete_stream($data->{session_id});
    }
    $self->send_connection_list($_) for $self->handle_list;
}

sub handle_server_response {
    my $self = shift;
    my $data = shift;

    if ($data->{response} eq 'sessions') {
        my @sessions = @{ $data->{sessions} };
        if (@sessions) {
            $self->clear_stream_data;
            for (@sessions) {
                $self->set_stream($_->{session_id} => $_);
            }
        }
    }
    elsif ($data->{response} eq 'stream') { ... }
}

sub send_connection_list {
    my $self   = shift;
    my $handle = shift;
    my $output;

    my $letter = 'a';
    my @stream_data = $self->get_stream(sort $self->stream_ids);
    foreach my $stream (@stream_data) {
        $output .= sprintf "%s) %s\r\n", $letter, $stream->{user};
        $letter++;
    }

    $output = "No active termcast sessions!\r\n" if !$output;

    $handle->push_write(CLEAR . "Users connected:\r\n\r\n$output");
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

