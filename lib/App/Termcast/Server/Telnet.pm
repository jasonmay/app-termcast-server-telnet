package App::Termcast::Server::Telnet;
# ABSTRACT: core of the Termcast telnet server
use Moose;
with 'Reflex::Role::Reactive'; # BBD prohibits MI

use Bread::Board::Declare;
use Reflex::Collection;

use IO qw(Socket::UNIX Socket::INET);

use YAML ();
use JSON ();

use App::Termcast::Connector;
use App::Termcast::Server::Telnet::Stream::Session;

has manager_socket_path => (
    is      => 'ro',
    isa     => 'Str',
    block   => sub { shift->get_param('config')->{socket} },
    lifecycle => 'Singleton',
    dependencies => ['config'],
);

sub _build_manager_socket_path {
    my $self = shift;
    return $self->config->{socket};
}

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
    block        => sub {
        my ($s, $self) = @_;
        my %constructor_params = %{ $s->params };

        return App::Termcast::Server::Telnet::Stream::Manager->new(
            %constructor_params,
            handle => $s->get_param('connector')->manager_socket,
        );
    },
    lifecycle    => 'Singleton',
    dependencies => {
        connection_pool   => 'connection_pool',
        session_pool      => 'session_pool',
        connector         => 'connector',
        telnet_dispatcher => 'telnet_dispatcher',
    },
);

has telnet_dispatcher => (
    is           => 'ro',
    isa          => __PACKAGE__.'::Dispatcher::Connection',
    dependencies => ['session_pool'],
    lifecycle    => 'Singleton',
);

has connector => (
    is           => 'ro',
    isa          => 'App::Termcast::Connector',
    dependencies => ['manager_socket_path'],
    lifecycle    => 'Singleton',
);

sub _new_session_obj_from_data {
    my $self = shift;
    my ($session) = @_;

    my $handle = $self->connector->make_socket($session);

    print "Connecting to $session->{socket}\n";

    my %params = (
        username        => $session->{user},
        last_active     => $session->{last_active},
        stream_id       => $session->{session_id},
        handle_path     => $session->{socket},
        connection_pool => $self->connection_pool,
        handle          => $handle,
        $session->{geometry} ? (
            cols => $session->{geometry}->[0],
            rows => $session->{geometry}->[1],
        ) : (),
    );

    # ugh long class names
    my $session_class = 'App::Termcast::Server::Telnet::Stream::Session';
    my $session_object = $session_class->new(%params);

    $self->session_pool->remember_stream(
        $session->{session_id} => $session_object,
    );

    $self->manager_stream->remember($session_object);
}

sub run {
    my $self = shift;

    $self->connector->request_sessions;

    my $sessions_cb = sub {
        my ($connector, @sessions) = @_;
        $self->_new_session_obj_from_data($_) for @sessions;
    };

    my $connect_cb = sub {
        my ($connector, $data) = @_;
        $self->_new_session_obj_from_data($data);
        my @connections = values %{$self->connection_pool->objects};
        foreach my $conn (@connections) {
            next if $conn->viewing;
            $self->telnet_dispatcher->send_connection_list($conn->handle);
        }
    };

    my $disconnect_cb = sub {
        my ($connector, $session_id) = @_;
        my @connections = values %{$self->connection_pool->objects};
        foreach my $conn (@connections) {
            $conn->_clear_viewing
                if $conn->viewing && $conn->viewing eq $session_id;
            $self->telnet_dispatcher->send_connection_list($conn->handle);
        }

        $self->session_pool->get_unix_stream($session_id)->stopped();
        $self->session_pool->forget_stream($session_id);
    };

    $self->connector->register_sessions_callback($sessions_cb);
    $self->connector->register_connect_callback($connect_cb);
    $self->connector->register_disconnect_callback($disconnect_cb);

    $self->watch($self->manager_stream);
    $self->watch($self->telnet_acceptor);

    $self->run_all();
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
