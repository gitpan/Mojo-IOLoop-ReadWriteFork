use Mojo::Base -strict;
use Mojo::IOLoop;
use Mojo::IOLoop::ReadWriteFork;
use Test::More;
use Test::Memory::Cycle;

$ENV{PATH} ||= '';
plan skip_all => 'telnet is missing' unless grep { -x "$_/telnet" } split /:/, $ENV{PATH};

my $address = 'localhost';
my $port    = Mojo::IOLoop::Server->generate_port;
my ($exit_value, $signal);
my $connected = 0;

# echo server
Mojo::IOLoop->server(
  {address => $address, port => $port},
  sub {
    my ($ioloop, $stream) = @_;
    $stream->on(
      read => sub {
        my ($stream, $chunk) = @_;
        diag "WRITE(I heard you say: $chunk)" if $ENV{HARNESS_IS_VERBOSE};
        $stream->write("I heard you say: $chunk");
      }
    );
  }
);

my $fork   = Mojo::IOLoop::ReadWriteFork->new;
my $output = '';
my $drain  = 0;

$fork->on(
  close => sub {
    (my $self, $exit_value, $signal) = @_;
    Mojo::IOLoop->stop;
  }
);

$fork->on(
  read => sub {
    my ($fork, $chunk) = @_;
    diag "READ($chunk)" if $ENV{HARNESS_IS_VERBOSE};
    $fork->write("hey\r\n", sub { $drain++; }) if $chunk =~ /Connected/;
    $fork->kill(15) if $chunk =~ /I heard you say/;
    $output .= $chunk;
  }
);

$fork->start(program => 'telnet', program_args => [$address, $port], conduit => 'pty',);

Mojo::IOLoop->timer(1 => sub { Mojo::IOLoop->stop });    # guard
Mojo::IOLoop->start;
like $output,   qr{Connected},              'Connected';
like $output,   qr{I heard you say:.*hey}s, 'got echo';
is $drain,      1,                          'got drain event';
is $exit_value, 0,                          'exit_value';
is $signal,     15,                         'signal';

done_testing;
