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
        remember_stream     => 'set',
        forget_stream       => 'delete',
    },
    default => sub { {} },
);

__PACKAGE__->meta->make_immutable;
no Moose;

1;
