package App::Termcast::Server::Telnet::Stream::Service;
use Moose;

use JSON ();

use App::Termcast::Server::Telnet::Stream::Session;

extends 'Reflex::Stream';

has session_pool => (
    is       => 'ro',
    isa      => 'App::Termcast::Server::Telnet::Stream::Pool',
    required => 1,
);

# {
#  response => "sessions",
#  sessions => [
#    {
#      geometry => [
#        80,
#        24
#      ],
#      last_active => "1305076517",
#      session_id => "9845f356-7b6b-11e0-9efa-3ff7049b7e5f",
#      socket => "/tmp/328u7FuQD3",
#      user => "jasonmay"
#    }
#  ]

sub on_data {
    my ($self, $args) = @_;

    warn "data: $args->{data}\n";

    my $data = JSON::decode_json($args->{data});

    if (not ref $data->{sessions} or ref($data->{sessions}) ne 'ARRAY') {
        warn 'invalid data into service stream: invalid "sessions" key';
        return;
    }

    foreach my $session (@{ $data->{sessions} }) {
        my $handle = IO::Socket::UNIX->new(
            Peer => $session->{socket},
        ) or do {
            warn $!;
            next;
        };

        my %params = (
            username    => $session->{user},
            last_active => $session->{last_active},
            session_id  => $session->{session_id},
            handle      => $handle,
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
    }

    #use Data::Dumper::Concise; die Dumper($data);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
