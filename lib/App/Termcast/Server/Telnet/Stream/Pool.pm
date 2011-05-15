package App::Termcast::Server::Telnet::Stream::Pool;
use Moose;

extends 'Reflex::Base';

has unix_streams => (
    is      => 'ro',
    isa     => 'HashRef',
    traits  => ['Hash'],
    handles => {
        unix_stream_objects => 'values',
        unix_stream_ids     => 'keys',
        get_unix_stream     => 'get',
    },
    default => sub { {} },
);

sub remember_stream {
    my $self = shift;
    my ($stream_id, $stream) = @_;

    $self->unix_streams->{$stream_id} = $stream;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
