package Bus::Driver;
use MooseX::Role::Parameterized;
 
parameter driver => (required => 1);

role {
  my $p = shift;
  my $driver = $p->driver;
  has $driver => (is => 'rw', handles => [qw(send)]);
};

no Moose;
1;


