package App::Termcast::Server::Telnet;
use Moose;

use Reflex::Collection;

extends 'Bread::Board::Container';

has '+name' => (default => __PACKAGE__);

sub BUILD {
    container $self => as {

        # broadcaster sockets
        service session_pool => (
            class => 'Reflex::Collection',
        );

        # users connected to telnet
        service connection_pool => (
            class => 'Reflex::Collection',
        );

        service telnet_acceptor => (
            class => 'App::Termcast::Server::Telnet::Acceptor',
            dependencies => [
                'conenction_pool',
                'session_pool',
                'telnet_dispatcher',
            ],
        );

        service service_connector => (
            class => 'Reflex::Base',
        );

        service telnet_dispatcher => (
            class => 'App::Termcast::Server::Telnet::Dispatcher::Connection',
        );

        service service_dispatcher => (
            class => 'App::Termcast::Server::Telnet::Dispatcher::Service',
        );
    };
}

sub run {
    my $self = shift;

    my $acceptor = $self->resolve(service => 'telnet_acceptor');

    $acceptor->run_all();
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
