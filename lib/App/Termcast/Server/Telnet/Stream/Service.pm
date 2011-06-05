package App::Termcast::Server::Telnet::Stream::Service;
use Moose;
extends 'Reflex::Stream';

use Reflex::Collection;

use JSON ();

use App::Termcast::Server::Telnet::Stream::Session;

has session_pool => (
    is       => 'ro',
    isa      => 'App::Termcast::Server::Telnet::Stream::Pool',
    required => 1,
);

has connection_pool => (
    is       => 'ro',
    isa      => 'Reflex::Collection',
    required => 1,
);

has telnet_dispatcher => (
    is       => 'ro',
    isa      => 'App::Termcast::Server::Telnet::Dispatcher::Connection',
    required => 1,
);

has_many session_collection => (
    handles => ['remember'],
);

sub _new_session_obj_from_packet {
    my $self = shift;
    my ($session) = @_;

    my $handle = IO::Socket::UNIX->new(
        Peer => $session->{socket},
    ) or do {
        warn $!;
        next;
    };

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

    $self->remember($session_object);
}

sub on_data {
    my ($self, $args) = @_;

    my $data = JSON::decode_json($args->{data});

    if ($data->{sessions}) {
        if (not ref $data->{sessions} or ref($data->{sessions}) ne 'ARRAY') {
            warn 'invalid data into service stream: invalid "sessions" key';
            return;
        }

        foreach my $session (@{ $data->{sessions} }) {
            $self->_new_session_obj_from_packet($session);
        }
    }
    elsif ($data->{notice}) {
        my @connections = values %{$self->connection_pool->objects};

        if ($data->{notice} eq 'connect') {
            my $session = $data->{connection};

            $self->_new_session_obj_from_packet($session);

            foreach my $conn (@connections) {
                next if $conn->viewing;
                $self->telnet_dispatcher->send_connection_list($conn->handle);
            }
        }
        elsif ($data->{notice} eq 'disconnect') {
            my $stream_id = $data->{session_id};

            foreach my $conn (@connections) {
                $conn->_clear_viewing
                    if $conn->viewing && $conn->viewing eq $stream_id;
                $self->telnet_dispatcher->send_connection_list($conn->handle);

            }

            $self->session_pool->get_unix_stream($stream_id)->stopped();
            $self->session_pool->forget_stream($stream_id);
            print "Disconnecting $stream_id\n";
        }
        # TODO handle geometry, etc
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
