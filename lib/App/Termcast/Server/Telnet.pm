package App::Termcast::Server::Telnet;
use Moose;

use Bread::Board;
use Reflex::Collection;

use IO::Socket::UNIX;

extends 'Bread::Board::Container';

has '+name' => (default => __PACKAGE__);

has service_socket_path => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has service_socket => (
    is      => 'ro',
    isa     => 'FileHandle',
    lazy    => 1,
    builder => '_build_service_socket',
);

sub _build_service_socket {
    my $self = shift;

    my $socket = IO::Socket::UNIX->new(
        Peer => $self->service_socket_path,
    );
}

sub BUILD {
    my $self = shift;
    container $self => as {

        # broadcaster sockets
        service session_pool => (
            class     => 'Reflex::Collection',
            lifecycle => 'Singleton',
        );

        # users connected to telnet
        service connection_pool => (
            class     => 'Reflex::Collection',
            lifecycle => 'Singleton',
        );

        service telnet_acceptor => (
            class     => 'App::Termcast::Server::Telnet::Acceptor',
            lifecycle => 'Singleton',
            dependencies => [
                'connection_pool',
                'session_pool',
                'telnet_dispatcher',
            ],
        );

        service service_stream => (
            class     => 'Reflex::Stream',
            lifecycle => 'Singleton',
            dependencies => { handle => 'service_handle' },
        );

        service service_handle => $self->service_socket;

        service telnet_dispatcher => (
            class     => 'App::Termcast::Server::Telnet::Dispatcher::Connection',
            lifecycle => 'Singleton',
        );

        service service_dispatcher => (
            class     => 'App::Termcast::Server::Telnet::Dispatcher::Service',
            lifecycle => 'Singleton',
        );
    };
}

sub run {
    my $self = shift;

    my $acceptor = $self->resolve(service => 'telnet_acceptor');

    $acceptor->run_all();
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
