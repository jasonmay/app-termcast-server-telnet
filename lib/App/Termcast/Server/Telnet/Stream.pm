package App::Termcast::Server::Telnet::Stream;
use Moose;

has dispatcher => (

);

__PACKAGE__->meta->make_immutable;
no Moose;

1;
