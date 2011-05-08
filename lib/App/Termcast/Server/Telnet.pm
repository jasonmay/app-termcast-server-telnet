package App::Termcast::Server::Telnet;
use Moose;

use Bread::Board;
use Reflex::Collection;

use IO qw(Socket::UNIX Socket::INET);

extends 'Bread::Board::Container', 'Reflex::Base';

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
    ) or die $!;

    return $socket;
}

has telnet_listener => (
    is      => 'ro',
    isa     => 'FileHandle',
    lazy    => 1,
    builder => '_build_telnet_listener',
);

sub _build_telnet_listener {
    my $self = shift;

    warn "load?";
    my $socket = IO::Socket::INET->new(
        LocalPort => 2323,
    ) or die $!;

    return $socket;
}

has config => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { YAML::LoadFile('etc/config.yml') },
    lazy    => 1,
);

sub BUILD {
    my $self = shift;
    container $self => as {

        service config => $self->config;

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

        service telnet_listener => $self->telnet_listener;
        service telnet_acceptor => (
            class     => __PACKAGE__.'::Acceptor',
            lifecycle => 'Singleton',
            dependencies => {
                connection_pool   => 'connection_pool',
                session_pool      => 'session_pool',
                telnet_dispatcher => 'telnet_dispatcher',
                listener          => 'telnet_listener',
                config            => 'config',
            },
        );

        service service_socket => $self->service_socket;
        service service_stream => (
            class     => 'Reflex::Stream',
            lifecycle => 'Singleton',
            dependencies => { handle => 'service_socket' },
        );

        service telnet_dispatcher => (
            class     => __PACKAGE__.'::Dispatcher::Connection',
            lifecycle => 'Singleton',
        );

        service service_dispatcher => (
            class     => __PACKAGE__.'::Dispatcher::Service',
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
