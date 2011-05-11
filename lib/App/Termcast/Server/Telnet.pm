package App::Termcast::Server::Telnet;
use Moose;

use Bread::Board::Declare;
use Reflex::Collection;

use IO qw(Socket::UNIX Socket::INET);

use YAML;
use JSON ();

has service_socket_path => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has service_socket => (
    is    => 'ro',
    isa   => 'FileHandle',
    block => sub {
        my ($service, $self) = @_;

        my $socket = IO::Socket::UNIX->new(
            Peer => $self->service_socket_path,
        ) or die $!;

        my $req_string = JSON::encode_json({request => 'sessions'});
        $socket->syswrite($req_string);
        print "Telnet -> Server (UNIX) loaded\n";

        return $socket;
    },
);

has telnet_listener => (
    is    => 'ro',
    isa   => 'FileHandle',
    block => sub {
        my $self = shift;

        my $socket = IO::Socket::INET->new(
            LocalPort => 2323,
            Listen    => 1,
            Reuse     => 1,
        ) or die $!;
        print "Telnet socket listening\n";

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
    block     => sub { Reflex::Collection->new( _owner => $_[1]->telnet_acceptor ) },
    lifecycle => 'Singleton',
);

has session_pool => (
    is        => 'ro',
    isa       => 'App::Termcast::Server::Telnet::Stream::Pool',
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
    isa          => 'App::Termcast::Server::Telnet::Stream::Service',
    lifecycle    => 'Singleton',
    dependencies => { handle => 'service_socket' },
);

has telnet_dispatcher => (
    is           => 'ro',
    isa          => __PACKAGE__.'::Dispatcher::Connection',
    dependencies => ['session_pool'],
    lifecycle    => 'Singleton',
);

has service_dispatcher => (
    is        => 'ro',
    isa       => __PACKAGE__.'::Dispatcher::Service',
    lifecycle => 'Singleton',
);

sub run {
    my $self = shift;

    my $acceptor = $self->telnet_acceptor;

    $acceptor->run_all();
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
