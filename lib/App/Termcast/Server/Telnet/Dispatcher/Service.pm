package App::Termcast::Server::Telnet::Dispatcher::Service;
use Moose;

sub dispatch {
    my $self = shift;
}

sub handle_notice {
    my $self = shift;
    my $data = shift;

    if ($data->{notice} eq 'connect') {
        $self->set_stream(
            $data->{connection}{session_id} => $data->{connection},
        );
    }
    elsif ($data->{notice} eq 'disconnect') {
        $self->delete_stream($data->{session_id});
    }
    $self->send_connection_list($_) for $self->handle_list;
}

sub handle_response {
    my $self = shift;
    my $data = shift;

    if ($data->{response} eq 'sessions') {
        my @sessions = @{ $data->{sessions} };
        if (@sessions) {
            $self->clear_stream_data;
            for (@sessions) {
                $self->set_stream($_->{session_id} => $_);
            }
        }
    }
}


__PACKAGE__->meta->make_immutable;
no Moose;

1;
