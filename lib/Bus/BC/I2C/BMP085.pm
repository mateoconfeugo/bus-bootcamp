package Bus::Driver;
use MooseX::Role::Parameterized;
 
parameter driver => (required => 1);

role {
  my $p = shift;
  my $driver = $p->driver;
  has $driver => (is => 'rw', handles => [qw(read write)]);
};

no Moose;
1;


package Bus::BC::I2C::BMP085;
use Moose;

with Bus::Driver => { driver => $self->config->{driver_type} || 'Bus::Pirate' };

use constant MSB => 0xf6;
use constant LSB => 0xf7;

has temperature => (is=>'ro', isa=>'Int', reader=>'calculate_temperature');
#has pressure => (is=>'ro', isa=>'Int', reader=>'calculate_pressure'););
has debug => (is=>'rw', isa=>'Bool', lazy_build=>1);
has uncompensated_temperature => (is=>'rw', isa=>'Int');
has MC => (is=>'rw', isa=>'Int');
has MD => (is=>'rw', isa=>'Int');
has AC6 => (is=>'rw', isa=>'Int');
has AC5 => (is=>'rw', isa=>'Int');

sub read_raw_temperature {
  my ($self) = @_;
  # Start new temperature measurement
  $self->write(0xf4, 0x2e);
  # read register 0xf6 (msb) and 0xf7 (lsb)
  my $msb = $self->read(MSB);
  my $lsb = $self->read(LSB);
  # Calculate uncompensated temperature
  my $raw = (($msb << 8) + $lsb);
  $self->uncompensated_temperatue($raw);
  warn "Uncompensated temperature value: $raw\n" if $self->debug();
  return $raw;
}

sub calculate_temperature {
  my ($self) = @_;
  my $x1 = ($self->uncompensated_temperature - $self->AC6) * $self->AC5 >> 15;
  my $x2 = ($self->MC << 11) / ($x1 + $self->MD);
  my $b5 = $x1 + $x2;
  my $temperature = ($b5 + 8) >> 4;
  return $temperature;
}

sub get_calibration {
  my ($self) = @_;
  #$self->i2c_write_data([0xee, 0xb2])
  my $msb = $self->read(0xb2);
  my $lsb = $self->read(0xb3);
  $self->AC5( ($msb << 8) + $lsb );
  warn "AC5 Calibration register:", $elf->AC5 if $self->debug;
  
  my $msb = $self->read(0xb4);
  my $lsb = $self->read(0xb5);
  $self->AC6( ($msb << 8) + $lsb );
  warn "AC6 Calibration register:", self.AC6 if $self->debug;
 
  $msb = $self->device->read(0xbc);
  $lsb = $self->read(0xbd);
  $self->MC( ($msb << 8) + $lsb );
  warn "MC Calibration register:", $self->MC if $self->debug;
 
  $msb = $self->read(0xbe);
  $lsb = $self->read(0xbf);
  $self->MD (($msb << 8) + $lsb );
  warn "MD Calibration register:", $self->MD if $self->debug;
}

sub _build_debug {
  $ENV{BC_BUS_DEBUG} ? return 1 : 0;
}

sub run {
  my $obj = __PACKAGE__->new();
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
