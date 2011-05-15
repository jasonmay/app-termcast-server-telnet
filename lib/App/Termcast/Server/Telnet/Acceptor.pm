package App::Termcast::Server::Telnet::Acceptor;
use Moose;

use App::Termcast::Server::Telnet::Stream::Connection;

extends 'Reflex::Acceptor';

has connection_pool => (
    is       => 'ro',
    isa      => 'Reflex::Collection',
    required => 1,
    handles  => {
        remember_connection => 'remember',
    }
);

has session_pool => (
    is       => 'ro',
    isa      => 'App::Termcast::Server::Telnet::Stream::Pool',
    required => 1,
    handles  => {
        remember_session => 'remember',
    }
);

has telnet_dispatcher => (
    is       => 'ro',
    isa      => 'App::Termcast::Server::Telnet::Dispatcher::Connection',
    required => 1,
);

sub on_accept {
    my ($self, $args) = @_;

    my $iac = join(
        '',
        (
            map { chr }
            (
                255, 251,  1, # iac will echo
                255, 251,  3, # iac will suppres go_ahead
                255, 254, 34, # iac wont linemode
            )
        )
    );
    $args->{socket}->syswrite($iac);
    $self->telnet_dispatcher->send_connection_list($args->{socket});

    my $stream = App::Termcast::Server::Telnet::Stream::Connection->new(
        handle     => $args->{socket},
        dispatcher => $self->telnet_dispatcher,
    );

    $self->remember_connection($stream);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
