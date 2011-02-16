package App::Termcast::Server::Telnet::Stream::Pool;
use Moose;

extends 'Reflex::Base';

with 'Reflex::Trait::Observed';

# XXX hashref of observed unix streams?
# XXX ETOOTIREDTOTHINK

__PACKAGE__->meta->make_immutable;
no Moose;

1;
