use Test::Routine;
use Test::Routine::Util;
use Test::More;
use Test::Moose;
use Moose::Util qw( apply_all_roles );
use Carp;

has config => (is=>'rw', lazy_build=>1);

sub BUILD {
  my  $self = shift;
  my @roles  = qw/Bus::I2C/;
  apply_all_roles($self, @roles);
  return $self;
}

test 'communicating with device on the i2c bus' => sub {
    my $self = shift;
    plan tests => 2;
    $self->write_via_i2c({message=>'help'});
    my $got_response = $self->read_via_i2c();
    like($got_response, qr/for more information/, 'serial port channel to mcu working');
};

test 'data communications methods' => sub {
    my $self = shift;
    plan tests => 2;

    my $got_response = $self->read_via_i2c();
    like($got_response, qr/for more information/, 'serial port channel to mcu working');
};



sub _build_config {
  my $self = shift;
  my $cfg = {}
  return $cfg;
}

run_me();
done_testing();
1;
