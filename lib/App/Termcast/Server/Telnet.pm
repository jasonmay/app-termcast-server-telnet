package App::Termcast::Server::Telnet;
use Moose;
with 'Reflex::Role::Reactive'; # BBD prohibits MI

use Bread::Board::Declare;
use Reflex::Collection;

use IO qw(Socket::UNIX Socket::INET);

use YAML ();
use JSON ();

has manager_socket_path => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has manager_socket => (
    is    => 'ro',
    isa   => 'FileHandle',
    block => sub {
        my ($manager, $self) = @_;

        my $socket = IO::Socket::UNIX->new(
            Peer => $self->manager_socket_path,
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
    isa       => __PACKAGE__.'::Stream::Pool',
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

has manager_stream => (
    is           => 'ro',
    isa          => __PACKAGE__.'::Stream::Manager',
    lifecycle    => 'Singleton',
    dependencies => {
        connection_pool   => 'connection_pool',
        session_pool      => 'session_pool',
        handle            => 'manager_socket',
        telnet_dispatcher => 'telnet_dispatcher',
    },
);

has telnet_dispatcher => (
    is           => 'ro',
    isa          => __PACKAGE__.'::Dispatcher::Connection',
    dependencies => ['session_pool'],
    lifecycle    => 'Singleton',
);

has manager_dispatcher => (
    is        => 'ro',
    isa       => __PACKAGE__.'::Dispatcher::Manager',
    lifecycle => 'Singleton',
);

sub run {
    my $self = shift;

    $self->watch($self->manager_stream);
    $self->watch($self->telnet_acceptor);

    $self->run_all();
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
