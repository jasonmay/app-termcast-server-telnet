#!perl
package App::Termcast::Server::Telnet;
use Moose;

use Time::Duration;
use JSON;

use Reflex::Collection;

use App::Termcast::Server::Telnet::Stream::Service;
use App::Termcast::Server::Telnet::Stream::Connection;

extends 'Reflex::Base';

with 'Reflex::Role::Accepting', 'Reflex::Role::Streaming';


=head1 NAME

App::Termast::Server::Telnet - telnet interface for the termcast server

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

has telnet_port => (
    is      => 'ro',
    isa     => 'Int',
    default => 2323,
);

has service_socket => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has listener => (
    is => 'ro',
    isa => 'FileHandle',
    lazy => 1,
    builder => '_build_listener',
);

sub _build_listener {
    my $self = shift;

    # TODO use IO::Socket::Telnet instead
    # I'm on a plane and was too dumb to set
    # up minicpan so I don't have ::Telnet
    # on me. whoops!
    my $l = IO::Socket::INET->new(
        LocalPort => 2323,
        Listen    => 1,
        Reuse     => 1,
    ) or die $!;

    warn "listening on 2323.\n";

    return $l;
}

has handle => (
    is => 'ro',
    isa => 'FileHandle',
    lazy => 1,
    builder => '_build_handle',
);

sub _build_handle {
    my $self = shift;

    my $s = IO::Socket::UNIX->new(
        Peer  => $self->service_socket,
    ) or die $!;

    $s->syswrite(JSON::encode_json({request => 'sessions'}));

    warn "connected to " . $self->service_socket . ".\n";
    return $s;
}

has_many streams => (
    handles => { remember_stream => 'remember' },
);

sub on_listener_accept {
    my ($self, $args) = @_;
    warn "ACCEPT";

    my $stream = App::Termcast::Server::Telnet::Stream::Connection->new(
        handle => $args->{socket},
    );

    my $iac = join(
        '',
        (
            map { chr }
            (
                255, 251,  1, # iac will echo
                255, 251,  3, # iac will suppres go_ahead
                255, 254, 34, # iac wont linemode
            )
        )
    );
    $self->handle->syswrite($iac);

    $self->remember_stream($stream);
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
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 METHODS


=head1 AUTHOR

Jason May C<< <jason.a.may@gmail.com> >>

=head1 LICENSE

This program is free software; you can redistribute it and::or modify it under the same terms as Perl itself.

