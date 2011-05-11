package App::Termcast::Server::Telnet::Dispatcher::Connection;
use Moose;

use constant CLEAR => "\e[2J\e[H";

has viewing => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    clearer => '_clear_viewing',
);

has session_pool => (
    is       => 'ro',
    isa      => 'App::Termcast::Server::Telnet::Stream::Pool',
    required => 1,
    handles => ['unix_stream_ids', 'unix_stream_objects'],
);

sub dispatch_telnet_input {
    my $self = shift;
    my ($handle, $buf) = @_;

    if ($self->viewing) {
        $self->dispatch_stream_inputs(@_);
    }
    else {
        $self->dispatch_menu_inputs(@_);
    }
}

sub dispatch_stream_inputs {
    my $self = shift;
    my ($handle, $buf) = @_;

    if ($buf eq 'q') {
        $self->stopped();
        $self->send_connection_list($handle);
    }
}

sub dispatch_menu_inputs {
    my $self = shift;
    my ($handle, $buf) = @_;

    if ($buf eq 'q') {
        $handle->syswrite(CLEAR);
        $self->stopped();
        return;
    }

    my $session = $self->get_stream_from_key($buf);

    if ($session) {
        $handle->session->viewing($session);
        $handle->push_write(CLEAR);

        my $file = $self->get_stream($session)->{socket};
        {
            my $fh = shift or die "$file: $!";
            my $h = AnyEvent::Handle->new(
                fh => $fh,
                on_read => sub {
                    my $h = shift;
                    $handle->push_write($h->rbuf);
                    $h->{rbuf} = '';
                },
                on_error => sub {
                    my ($h, $fatal, $error) = @_;

                    if ($fatal) {
                        $handle->session->_clear_viewing;
                        $handle->session->_clear_stream_handle;
                        $self->send_connection_list($handle);
                    }
                    else {
                        warn $error;
                    }
                }
            );
            $handle->session->stream_handle($h);
        };
    }
    else {
        $self->send_connection_list($handle);
    }
}

sub send_connection_list {
    my $self   = shift;
    my $handle = shift;
    my $output;

    print "Sending stream menu to the customer\n";
    my $letter = 'a';
    my @stream_data = $self->unix_stream_objects;
    foreach my $stream (@stream_data) {
        $output .= sprintf "%s) %s - Active %s\r\n",
                   $letter,
                   $stream->{user},
                   ago(time() - $stream->{last_active});
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
