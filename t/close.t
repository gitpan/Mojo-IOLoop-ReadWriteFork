use Mojo::Base -strict;
use Mojo::IOLoop::ReadWriteFork;
use Test::More;
use Test::Memory::Cycle;

my $fork   = Mojo::IOLoop::ReadWriteFork->new;
my $output = '';

$fork->on(close => sub { Mojo::IOLoop->stop; });
$fork->on(error => sub { diag "error: @_" });
$fork->on(read  => sub { $output .= $_[1]; });
$fork->write("line one\nline two\n", sub { shift->close('stdin'); });
$fork->run(sub { print while <>; print "FORCE\n"; });

Mojo::IOLoop->timer(3 => sub { Mojo::IOLoop->stop });    # guard
Mojo::IOLoop->start;

like $output, qr/line one\nline two\nFORCE\n/, 'close' or diag $output;

done_testing;
