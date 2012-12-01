package Bus::Driver;
use MooseX::Role::Parameterized;
 
parameter backend => (required => 1);
parameter config => (isa=>'HashRef');

role {
  my $p = shift;
  Class::MOP::load_class($p->backend);
  my $backend = $p->backend->new({config=>$p->config});

  method 'send' => sub {
     	my ($self, $args) = @_;
	$self->driver($backend);
	$backend->send($args);
  }
 
};

no Moose;
1;


