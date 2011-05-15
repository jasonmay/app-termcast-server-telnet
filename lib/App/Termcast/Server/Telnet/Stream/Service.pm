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

has_many session_collection => (
    handles => ['remember'],
);

sub on_data {
    my ($self, $args) = @_;

    warn "data: $args->{data}\n";

    my $data = JSON::decode_json($args->{data});

    if ($data->{sessions}) {
        if (not ref $data->{sessions} or ref($data->{sessions}) ne 'ARRAY') {
            warn 'invalid data into service stream: invalid "sessions" key';
            return;
        }

        foreach my $session (@{ $data->{sessions} }) {
            warn $session->{socket};
            my $handle = IO::Socket::UNIX->new(
                Peer => $session->{socket},
            ) or do {
                warn $!;
                next;
            };

            warn "Connecting to $session->{socket}";

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
    }
    elsif ($data->{notice}) {
        warn "got a 'notice' message";
    }

    #use Data::Dumper::Concise; die Dumper($data);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
