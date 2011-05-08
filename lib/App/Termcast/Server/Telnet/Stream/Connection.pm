package App::Termcast::Server::Telnet::Stream::Connection;
use Moose;

extends 'Reflex::Stream';

has viewing => (
    is  => 'rw',
    isa => 'Maybe[Str]',
    clearer => '_clear_viewing',
);

has page => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has dispatcher => (
    is => 'ro',
    isa => 'App::Termcast::Server::Telnet::Dispatcher::Connection',
);

sub on_data {
    my ($self, $args) = @_;

    warn "data: $args->{data}\n";
    $self->dispatcher->dispatch_telnet_input($args->{data});
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
