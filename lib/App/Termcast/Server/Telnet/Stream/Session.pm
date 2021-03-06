package App::Termcast::Server::Telnet::Stream::Session;
use Moose;
extends 'Reflex::Stream';

use MooseX::Types::DateTime;
use DateTime;

has connection_pool => (
    is       => 'ro',
    isa      => 'Reflex::Collection',
    required => 1,
);

has cols => (
    is      => 'rw',
    isa     => 'Int',
    default => 80,
);

has rows => (
    is      => 'rw',
    isa     => 'Int',
    default => 24,
);

has last_active => (
    is      => 'ro',
    isa     => 'DateTime',
    default => sub { DateTime->now },
    coerce  => 1,
);

has stream_id => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has username => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has buffer => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

sub on_data {
    my ($self, $args) = @_;


    $self->{buffer} .= $args->{data};
    if ($args->{data} =~ s/.+\e\[2J//s) {
        $self->{buffer} = $args->{data};
    }

    my @connections = $self->connection_pool->get_objects;

    foreach my $conn (@connections) {
        next unless $conn->viewing && $conn->viewing eq $self->stream_id;

        $conn->handle->syswrite($args->{data});
    }
}

sub on_error { warn $_[0]->handle }

__PACKAGE__->meta->make_immutable;
no Moose;

1;
