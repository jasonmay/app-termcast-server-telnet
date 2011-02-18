package App::Termcast::Server::Telnet::Stream::Service;
use Moose;

extends 'Reflex::Stream';

sub on_data {
    my ($self, $args) = @_;

    warn "data: $args->{data}\n";
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
