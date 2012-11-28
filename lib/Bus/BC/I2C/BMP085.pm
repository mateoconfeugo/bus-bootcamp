package Bus::Driver;
use MooseX::Role::Parameterized;
 
parameter device => (required => 1);

role {
  my $p = shift;
  my $device = $p->device;
  has $device => (is => 'rw', handles => [qw(enter_spi_mode
					     enter_i2c_mode
					     enter_uart_mode
					     
					   )]);
};

no Moose;
1;


package Bus::BC::I2C::BMP085;
use Moose;
use Bus::Pirate;

with Bus::Driver => { device => 'Bus::Pirate' };

has temperature => (is=>'rw', isa=>'Int');
has pressure => (is=>'rw', isa=>'Int');
has debug => (is=>'rw', isa=>'Bool', lazy_build=>1);
has uncompensated_temperature => (is=>'rw', isa=>'Int');
has MC => (is=>'rw', isa=>'Int');
has MD => (is=>'rw', isa=>'Int');
has AC6 => (is=>'rw', isa=>'Int');
has AC5 => (is=>'rw', isa=>'Int');

sub read_raw_temperature {
  my ($self) = @_;
  # Start new temperature measurement
  # write 0x2E into register 0xf4 and wait for 4.5milliseconds
  $self->i2c_control_register(0xf4, 0x2e);
  # read register 0xf6 (msb) and 0xf7 (lsb)
  my $msb = $self->get_i2c_register(0xf6);
  my $lsb = $self->get_i2c_register(0xf7);
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
  my $msb = $self->get_register(0xb2);
  my $lsb = $self->get_register(0xb3);
  $self->AC5( ($msb << 8) + $lsb );
  print "AC5 Calibration register:", $elf->AC5 if $self->debug;
  
  my $msb = $self->get_register(0xb4);
  my $lsb = self.get_register(0xb5);
  $self->AC6( ($msb << 8) + $lsb );
  print "AC6 Calibration register:", self.AC6 if $self->debug;
 
  $msb = $self->get_register(0xbc);
  $lsb = $self->get_register(0xbd);
  $self->MC( ($msb << 8) + $lsb );
  print "MC Calibration register:", $self->MC if $self->debug;
 
  $msb = $self->get_register(0xbe);
  $lsb = $self.get_register(0xbf);
  $self->MD (($msb << 8) + $lsb );
  print "MD Calibration register:", $self->MD if $self->debug;
}

[ - indicates a start bit
0xee - is the write address of our device
0xac - is the register we want to read
[ - indicates a new start bit, to start a new command
0xef - is the read address of our device
r - command to read one byte
] – indicates a stop bit


sub control_register {
  my ($self, $register, $value) = @_;
  #
  # [0xee 0xac [0xef r]
   [$write_address, $read_address, 
}

sub get_register {
  my ($self, $register) = @_;
}

sub _build_debug {
  $ENV{BC_BUS_DEBUG} ? return 1 : 0;
}

sub run {
  my $obj = __PACKAGE__->new();
  my $current_temperature = 
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
