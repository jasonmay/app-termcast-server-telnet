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
    is      => 'ro',
    isa     => 'Int',
    default => 80,
);

has rows => (
    is      => 'ro',
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

sub BUILD { warn 'BUILD: ' . $_[0]->handle }
sub DEMOLISH { warn 'DESTROY: ' . $_[0]->handle }

sub on_data {
    my ($self, $args) = @_;
    #warn "data: $args->{data}";

    my @connections = values %{$self->connection_pool->objects};

    foreach my $conn (@connections) {
        next unless $conn->viewing && $conn->viewing eq $self->stream_id;

        $conn->put($args->{data});
    }
}

sub on_error { warn $_[0]->handle }

__PACKAGE__->meta->make_immutable;
no Moose;

1;
