package App::Termcast::Server::Telnet::Stream::Session;
use Moose;
use MooseX::Types::DateTime;
use DateTime;

has cols => (
    is  => 'ro',
    isa => 'Int',
    default => 80,
);

has rows => (
    is  => 'ro',
    isa => 'Int',
    default => 24,
);

# {
#  response => "sessions",
#  sessions => [
#    {
#      geometry => [
#        80,
#        24
#      ],
#      last_active => "1305076517",
#      session_id => "9845f356-7b6b-11e0-9efa-3ff7049b7e5f",
#      socket => "/tmp/328u7FuQD3",
#      user => "jasonmay"
#    }
#  ]

has last_active => (
    is     => 'ro',
    isa    => 'DateTime',
    default => sub { DateTime->now },
    coerce => 1,
);

has session_id => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has handle => (
    is       => 'ro',
    isa      => 'IO::Socket::UNIX',
    required => 1,
);

has username => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

__PACKAGE__->meta->make_immutable;
no Moose;

1;
