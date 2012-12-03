package Bus::I2C::BMP085;

# DEPENDENCIES
use Moose;
use Log::Log4perl qw(:easy);
use Moose::Util qw(apply_all_roles);
use Try::Tiny;
use Bus::Pirate;

 
# ROLES - more in constructor
with qw(Throwable);          
with 'MooseX::Log::Log4perl::Easy';
with 'Bus::Time::Util';
with 'Bus::Meta::Util';
with 'Bus::Exception::Engine';
with 'Bus::Math';

# COMPILE TIME DIRECTIVES 
BEGIN { 
  Log::Log4perl->easy_init(); 
}

# CONSTANTS
use constant INPUT => 0xee;
use constant OUTPUT => 0xef;
use constant RAW_MEASUREMENT_MSB => 0xf6;
use constant RAW_MEASUREMENT_LSB => 0xf7;
use constant RAW_ADDR => 0xf4;
use constant RAW_VAL => 0x2e;
use constant OSS => 0x2e;
use constant POWER => 0x8;
use constant PULLUPS => 0x4;
use constant AUX => 0x2;
use constant CS => 0x1;
use constant MOSI_PIN => 0x01;
use constant CLK => 0x02;
use constant MISO_PIN => 0x04;
use constant CS_PIN => 0x08;
use constant AUX_PIN => 0x10;
use constant PULLUP_PIN => 0x20;
use constant POWER_PIN => 0x40;

# ATTRIBUTES
has temperature => (is=>'ro', isa=>'Int'); #, reader=>'calculate_temperature');
has pressure => (is=>'ro', isa=>'Int'); #, reader=>'calculate_pressure');
has coefficient_map => (is=>'ro', isa=>'HashRef[ArrayRef]', lazy_build=>1);
has timeout => (is=>'ro', isa=>'HashRef[ArrarRef]', defaults=>.02);
has AC1 => (is=>'rw', isa=>'Int', lazy_build=>1);
has AC2 => (is=>'rw', isa=>'Int', lazy_build=>1);
has AC3 => (is=>'rw', isa=>'Int', lazy_build=>1);
has AC4 => (is=>'rw', isa=>'Int', lazy_build=>1);
has AC5 => (is=>'rw', isa=>'Int', lazy_build=>1);
has AC6 => (is=>'rw', isa=>'Int', lazy_build=>1);
has B1 => (is=>'rw', isa=>'Int', lazy_build=>1);
has B2 => (is=>'rw', isa=>'Int', lazy_build=>1);
has B3 => (is=>'rw' );
has B4 => (is=>'rw' );
has B5 => (is=>'rw' );
has B6 => (is=>'rw' );
has B7 => (is=>'rw' );
has MB => (is=>'rw', isa=>'Int', lazy_build=>1);
has MC => (is=>'rw', isa=>'Int', lazy_build=>1);
has MD => (is=>'rw', isa=>'Int', lazy_build=>1);
#has driver=> (is=>'rw', lazy_build=>1, handles=>['send']);
has driver => (is=>'rw', handles=>['send', 'i2c_bulk_transfer']);
has config => (is=>'rw', isa=>'HashRef');

sub _build_driver {
    my $self = shift;
    return Bus::Pirate->new({config=>$self->config})
}

# CONSTRUCTOR

sub polymorphism_ala_carte {
   my $self = shift;
   my $c = $self->config;
   my $interface = $c->{active_interface};
   my $implementation = $c->{$interface};
   my $module =  $implementation;
   apply_all_roles($self, $interface, {backend => $module, config => $c});
   return $self;
};

sub calculate_temperature {
  my ($self) = @_;
  $self->write(RAW_ADDR, RAW_VAL); # Start temperature measurement
  my $uncompensated_temperature = ( ($self->read(RAW_MEASUREMENT_MSB) << 8) + $self->read(RAW_MEASUREMENT_LSB) );
  my $x1 = ($uncompensated_temperature - $self->AC6) * $self->AC5 >> 15;
  my $x2 = ($self->MC << 11) / ($x1 + $self->MD);
  my $b5 = $x1 + $x2;
  $self->B5(5);
  my $temperature = ($b5 + 8) >> 4;
  $self->log_info("temperature: $temperature");
  return $temperature;
}

around 'calculate_pressure' => sub {
    my ($method, $self, $args) = @_;
    $self->calculate_temperature();
    return $self->$method();
};

sub calculate_pressure {
  my ($self) = @_;
  $self->calculate_temperature();
  $self->write(0xf4, (0x34 + (OSS << 6) )); # Start pressure measurement
  my $lsb =$self->read(RAW_MEASUREMENT_LSB);
  my $msb = $self->read(RAW_MEASUREMENT_MSB); 
  my $up = ( ($msb << 16) + ($lsb + 8) ) >> (8 - OSS);
  my $b6 = $self->B5  - 4000;   
  my $x1 = ($self->B2 * ($b6 * ($b6/(2**12))))/(2**11);
  my $x2 = ($self->AC2 * ($b6/(2**11)));
  my $x3 = $x1 + $x2;
  my $b3 = ((($self->AC1 * 4) + $x3) << OSS + 2)/4;
  $x1 = ($self->AC3 * $b6)/(2**13);
  $x2 = ($self->B1  * (($b6 * $b6)/(2**12)))/(2**16);
  $x3 = (($x1 + $x2) + 2 ) / (2**2);
  my $b4 = ($self->AC4 * ($x3 + 32786))/(2**15); 
  my $b7 = ($up - $b3) * (5000 >> OSS);
  my $p;
  if($b7 < 0x80000000) {
    $p = ($b7 *2) / $b4
  }
  else {
    $p = ($b7/$b4)/4;
  }
  $x1 = ($p/(2**8)) * ($p/(2**8));
  $x1 = ($x1 * 3038) / (2**16);
  $x2 = (-7357 * $p ) / (2**16);
  my $pressure = $p + ($x1 + $x2  + 3791)/(2**4);
  $self->B3($b3);
  $self->B4($b4);
  $self->B6($b6);
  $self->B7($b7);
  $self->log_info("pressure: $pressure");
  return $pressure;
}

sub read { 
 my ($self, $register_address) = @_;
# my $value = $self->read_register(OUTPUT, $address); 
 my $value = $self->get_register({address=>$register_address}); 
 $self->log_debug("read $value from address: $register_address");
 return $value;
}

sub write { 
  my ($self, $address, $value) = @_;
  $self->log_debug("writing $value to address: $address");
  $self->write_register(INPUT, $address, $value); 
}

sub write_register {
  my ($self, $write_address, $address, $value) = @_;
  pause({for=>4.5, units=>'ms'});
  my $data = [$write_address, $address, $value];
  $self->i2c_send_start_bit();
  $self->i2c_bulk_transfer({data=>$data});
  $self->log_debug("sending data: $data");
  $self->i2c_send_stop_bit();
}

sub control_register {
    my ($self, $args) = @_;
    my $write_addr = $args->{write_address} || INPUT;
    my $register = $args->{register};
    my $val = $args->{value};
    my $data = [ $write_addr, $register, $val];
    $self->i2c_send_start_bit();
    $self->i2c_bulk_transfer({data=>$data});
    $self->i2c_send_stop_bit();
}

sub get_register {
    my ($self, $args) = @_;
    my $write_addr = $args->{write_address} || INPUT;
    my $address = $args->{address};
    my $data = [ $write_addr, $address];
    $self->i2c_send_start_bit();
    $self->i2c_bulk_transfer({data=>$data});
    $self->i2c_send_start_bit();
    $self->i2c_bulk_transfer({data=>[OUTPUT]});
    $self->i2c_send_stop_bit();
    my $buffer = unpack('C*', $self->i2c_read_byte());
    return $buffer;
}

sub get_coefficient {
  my ($self, $coefficient) = @_;
  my ($msb_addr, $lsb_addr) = @{$self->coefficient_map->{$coefficient}};
  my $msb = $self->read($msb_addr);
  my $lsb = $self->read($lsb_addr);
  return (($msb << 8) + $lsb);
}

sub _build_coefficient_map {
  return { 
	  AC1 => [0xaa, 0xab],
	  AC2 => [0xac, 0xad],
	  AC3 => [0xae, 0xaf],
	  AC4 => [0xb0, 0xb1],
	  AC5 => [0xb2, 0xb3],
	  AC6 => [0xb4, 0xb5],
	  B1 =>  [0xb6, 0xb7],
	  B2 =>  [0xb8, 0xb9],
	  MC =>  [0xba, 0xbb],
	  MB =>  [0xbc, 0xbd],
	  MD =>  [0xbe, 0xbf],
	 };
}

sub _build_AC1 { $_[0]->get_coefficient('AC1') }
sub _build_AC2 { $_[0]->get_coefficient('AC2') }
sub _build_AC3 { $_[0]->get_coefficient('AC3') }
sub _build_AC4 { $_[0]->get_coefficient('AC4') }
sub _build_AC5 { $_[0]->get_coefficient('AC5') }
sub _build_AC6 { 
    $_[0]->get_coefficient('AC6') 
}
sub _build_B1  { $_[0]->get_coefficient('B1') }
sub _build_B2  { $_[0]->get_coefficient('B2') }
sub _build_MB  { $_[0]->get_coefficient('MB') }
sub _build_MC  { $_[0]->get_coefficient('MC') }
sub _build_MD  { $_[0]->get_coefficient('MD') }

sub BUILD { 
    my ($self, $args) = @_;
  
    # Plugin custom exception handling;
    $self->exception_dispatch_table->{BMP085} = sub { 
	my ($me, $e) = @_;
	warn "In a custom exception handler for BMP085";
	$self->log_debug("BMP085 Exception Thrown");
	$self->default_exception_handler($_[0]);
	my $the_fix = sub { $self->i2c_start_sniffer() };
	return $the_fix if $self->healing;
	$self->throw({error=>$e, message=>'Generic BMP085 Exception'});
    };
    
    # Connect interface to backend implementation via
    $self = $self->polymorphism_ala_carte(); 
    
    # I2C role applied now because it requires methods from the backend
    apply_all_roles($self, 'Bus::I2C'); 
    
    # Configure the hardware
    my $success = 0;
    try { 
	$success = $self->enter_i2c();
	try { 
	    $success = $self->i2c_cfg_pins();
	    try { 
		$success = $self->i2c_set_speed();
	    } catch {$self->throw({message=>'unable to configure bus speed for i2c mode',
				   exception=>'BusPirate', error=>$_})};
	} catch { $self->throw({message=>'unable to configure pins for i2c mode', 
				exception=>'BusPirate', error=>$_ })};
    } catch { $self->throw({ message=>'unable to enter into ic2 bus mode', 
			     exception=>'BusPirate', error=>$_})};
    $success ? 
	return $self : 
	$self->throw({exception=>'BMP085', error=>$args, message=>'unable to configure/setup bmp085'});
}

sub run {
  my $cfg = {
	     'active_interface' => 'Bus::Driver',
	     'Bus::Driver'=> 'Bus::Pirate',
	     file=>'/dev/tty.usbserial-A800KBPV'
	    };

  my $bmp085 =  try { 
      __PACKAGE__->new({config=>$cfg});
  } catch {
      warn "unable to create the bmp due to error: $_\n"
  };
  
  try {
      my $foo = $bmp085->leach();
      my $bin = $bmp085->dec2bin(11);
      my $hex = $bmp085->bin2hex($bin);
      $hex = $bmp085->dec2hex(11);
      my $temperature = $bmp085->calculate_temperature();
      my $pressure = $bmp085->calculate_pressure();
      warn "The current temperature is $temperature\n";
      warn "The current pressure is $pressure\n";
  } catch {
      $bmp085->handle_exception({exception=>'BMP085', error=>$_, message=>"problems while reading sensors"});
  };
}

run() unless caller;

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

# ABSTRACT: Temperatue and Pressure Sensor that communicates via I2C

=pod

=head1 NAME

Bus::Pirate - Temperatue and Pressure Sensor that communicates via I2C

=head1 VERSION

version 0.0.1

=head1 SYNOPSIS

=over 4

  use Bus::Pirate;
  use Try::Tiny;

  my $bmp085 = Bus::I2C::BMP085->new();
  my $temperature = $bmp085->temperature();
  my $pressure = $bmp085->pressure();

=back

=head1 DESCRIPTION

This hardware is a combination temperature / pressure  sensor.  Configuration and reading the sensor is accomplished via the i2c bus.  The hardware can interface with the module via the Bus::Pirate or GPIO.  The idea is you start with the BUS::Pirate driver and then move to the GPIO::Driver.  All of this can be done via a configuration attribute.

=head1 METHODS

=over 4

=item B<< Bus::I2C::BMP085->new() >>

Constructor method that sets up a sensor for reading;

=back

=head1 ATTRIBUTES

=over 4

=item B<< $object>temperatue) >>

get the current temperature from the sensor.

=item B<< $object->pressure) >>

get the current pressure from the sensor.

=back

=head1 BUGS

See L<Bus-Pirate/BUGS> for details on reporting bugs.

=head1 AUTHOR

Bus::Pirate is maintained by Matt Burns

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Matthew Burns

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
