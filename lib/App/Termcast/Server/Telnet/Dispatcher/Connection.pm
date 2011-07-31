package App::Termcast::Server::Telnet::Dispatcher::Connection;
use Moose;

use Time::Duration;

use constant CLEAR => "\e[2J\e[H";

has session_pool => (
    is       => 'ro',
    isa      => 'App::Termcast::Server::Telnet::Stream::Pool',
    required => 1,
    handles => ['unix_stream_ids', 'unix_stream_objects'],
);

sub dispatch_telnet_input {
    my $self = shift;
    my ($stream) = @_;

    if ($stream->viewing) {
        $self->dispatch_stream_inputs(@_);
    }
    else {
        $self->dispatch_menu_inputs(@_);
    }
}

sub dispatch_stream_inputs {
    my $self = shift;
    my ($stream, $buf) = @_;

    if ($buf eq 'q') {
        $stream->_clear_viewing;
        $self->send_connection_list($stream->handle);
    }
}

sub dispatch_menu_inputs {
    my $self = shift;
    my ($stream, $buf) = @_;

    if ($buf eq 'q') {
        $stream->put(CLEAR);
        $stream->stopped();
        return;
    }

    my $session = $self->get_stream_from_key($buf);

    if ($session) {
        $stream->viewing($session);
        $stream->handle->syswrite(CLEAR);

        #my $file = $self->session_pool->get_unix_stream($session)->handle_path;

        print "viewing $session\n";

        $stream->handle->syswrite($self->session_pool->get_unix_stream($session)->buffer);
    }
    else {
        $self->send_connection_list($stream->handle);
    }
}

sub send_connection_list {
    my $self   = shift;
    my $handle = shift;
    my $output;

    # TODO, log: print "Sending stream menu to the customer\n";
    my $letter = 'a';
    my @stream_data = $self->unix_stream_objects;
    foreach my $stream (@stream_data) {
        $output .= sprintf "%s) %s (%s) - Active %s\r\n",
                   $letter,
                   $stream->username,
                   $stream->cols . 'x' . $stream->rows,
                   ago(time() - $stream->last_active->epoch);
        $letter++;
    }

    $output = "No active termcast sessions!\r\n" if !$output;

    $handle->syswrite(CLEAR . "Users connected:\r\n\r\n$output");
}

sub get_stream_from_key {
    my $self = shift;
    my $key = shift;
    my %id_map;

    my @stream_ids = $self->unix_stream_ids;
    my @keys       = ('a' .. 'p', 'r' .. 'z', 'A' .. 'Z');
    @id_map{ map { $keys[$_] } 0 .. @stream_ids } = sort @stream_ids;

    return $id_map{$key};
}


__PACKAGE__->meta->make_immutable;
no Moose;

1;
