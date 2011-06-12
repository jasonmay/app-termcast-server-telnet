package App::Termcast::Server::Telnet::Stream::Manager;
use Moose;
extends 'Reflex::Stream';

use Reflex::Collection;

use JSON ();

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

has connector => (
    is       => 'ro',
    isa      => 'App::Termcast::Connector',
    required => 1,
);

has_many session_collection => (
    handles => ['remember'],
);

sub on_data {
    my ($self, $args) = @_;

    $self->connector->dispatch( $args->{data} );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
