use Test::Routine;
use Test::Routine::Util;
use Test::More;
use Test::Moose;
use Moose::Util qw( apply_all_roles );
use Carp;
use Bus::I2C::BMP085;

has config => (is=>'rw', lazy_build=>1);
has test_cfg_file_path => (is=>'rw', lazy_build=>1);
has sensor => (is=>'rw', lazy_build=>1);

test 'measure temperatue' => sub {
    my $self = shift;
    my $sensor = $self->sensor;
    plan tests => 3;
    $sensor->calibrate();
    my $raw = $sensor->read_raw_temperature();
    my $temperature = $sensor->calculate_temperature();
};

sub _build_sensor {
  my $self = shift;
  return Bus::I2C::BMP085->new({config=>$self->config});
}

sub _build_config {
  my $self = shift;
  my $cfg = {driver_type=>'Bus::Pirate'};
  return $cfg;
}

run_me();
done_testing();
1;
