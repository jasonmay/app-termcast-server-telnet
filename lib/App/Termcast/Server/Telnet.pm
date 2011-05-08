package App::Termcast::Server::Telnet;
use Moose;

use Bread::Board::Declare;
use Reflex::Collection;

use IO qw(Socket::UNIX Socket::INET);

use YAML;

has service_socket_path => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has service_socket => (
    is    => 'ro',
    isa   => 'FileHandle',
    block => sub {
        my $self = shift;

        my $socket = IO::Socket::UNIX->new(
            Peer => $self->service_socket_path,
        ) or die $!;

        return $socket;
    },
);

has telnet_listener => (
    is    => 'ro',
    isa   => 'FileHandle',
    block => sub {
        my $self = shift;

        warn "load?";
        my $socket = IO::Socket::INET->new(
            LocalPort => 2323,
            Listen    => 1,
            Reuse     => 1,
        ) or die $!;

        return $socket;
    },
    lifecycle => 'Singleton',
);

has config => (
    is        => 'ro',
    isa       => 'HashRef',
    block     => sub {YAML::LoadFile('etc/config.yml') },
    lifecycle => 'Singleton',
);

has connection_pool => (
    is        => 'ro',
    isa       => 'Reflex::Collection',
    lifecycle => 'Singleton',
);

has session_pool => (
    is        => 'ro',
    isa       => 'Reflex::Collection',
    lifecycle => 'Singleton',
);

has telnet_acceptor => (
    is           => 'ro',
    isa          => __PACKAGE__.'::Acceptor',
    lifecycle    => 'Singleton',
    dependencies => {
        connection_pool   => 'connection_pool',
        session_pool      => 'session_pool',
        telnet_dispatcher => 'telnet_dispatcher',
        listener          => 'telnet_listener',
        config            => 'config',
    },
);

has service_stream => (
    is           => 'ro',
    isa          => 'Reflex::Stream',
    lifecycle    => 'Singleton',
    dependencies => { handle => 'service_socket' },
);

has telnet_dispatcher => (
    is        => 'ro',
    isa       => __PACKAGE__.'::Dispatcher::Connection',
    lifecycle => 'Singleton',
);

has service_dispatcher => (
    is        => 'ro',
    isa       => __PACKAGE__.'::Dispatcher::Service',
    lifecycle => 'Singleton',
);

sub run {
    my $self = shift;

    my $acceptor = $self->get_service('telnet_acceptor')->get;

    $acceptor->run_all();
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
