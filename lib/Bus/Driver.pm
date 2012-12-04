package Bus::Driver;
# ABSTRACT: Driver Interface that allows for hotswapable back end configurations
use MooseX::Role::Parameterized;
 
parameter backend => (required => 1);
parameter config => (isa=>'HashRef');

role {
  my $p = shift;
  Class::MOP::load_class($p->backend);
  my $backend = $p->backend->new({config=>$p->config});

  has driver => (is=>'rw', handles=>['send', 'i2c_bulk_transfer', 'setup_i2c']);

  method 'send' => sub {
     	my ($self, $args) = @_;
	$self->driver($backend);
	$backend->send($args);
  }
 
};

no Moose;
1;


