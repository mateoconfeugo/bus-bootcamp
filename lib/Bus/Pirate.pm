package Bus::Pirate;
# ABSTRACT:  Access the hardware resources via tool testing various types of data bus commonly used with micro controllers.

use Moose;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use Bus::Exception;

# ROLES
with qw(Throwable);              
with qw(Bus::Time::Util);        
with qw(Bus::Serial);            
with qw(Bus::Debug);             
with qw(Bus::Exception::Engine); 
with qw(Bus::I2C);               
with qw(Bus::Meta::Util);
with qw(Bus::Math);

# CONSTANTS
use constant SETIN => "\x40"; #set pin direction input(1) output (0), returns read
use constant SETON => "\x80"; #set pins on (1), returns read
# Bits are assigned as such:
use constant MOSI => "\x01";
use constant CLK => "\x02";
use constant MISO => "\x04";
use constant CS => "\x08";
use constant AUX => "\x10";
use constant PULLUP => "\x20";
use constant POWER => "\x40";

# ATTRIBUTES
has io_mode => (is=>'rw', isa=> enum([qw(binary user)]) );
has bus_mode => (is=>'rw', isa=> enum([qw(i2c spi uart 1wire)]) );
has modes => (is=>'ro', isa=>'HashRef', lazy_build=>1);
has config => (is=>'rw', isa=>'HashRef', requires=>1);

# CONSTRUCTOR 
sub BUILD {
    my $self = shift;
    $self->exit_binary_mode();
    $self->enter_binary_mode();
}

# INTERFACE METHODS
sub send {
   my ($self, $args) = @_;
   my $msg = $args->{message};
   my $duration = $args->{delay} || .02;
   my $how_many = $args->{read_length} || 5;
   $self->serial_port->write("$msg");
   $self->pause({for=>$duration});
   my $output = $self->serial_port->read($how_many);
   return $output;
}

sub i2c_bulk_transfer {
  my ($self, $args) = @_;
  my $byte_data = $args->{data};
  my $byte_count = scalar @$byte_data;
  return if $byte_data eq 'None';
  my $cmd_byte = (0x10 | ($byte_count-1));
  my $binary = $self->dec2bin($cmd_byte);
  $self->serial_port->write(pack('C*', $cmd_byte));
  my $data = $self->serial_port->read(255);
  my $hex = $self->serial2hex($data) if $data;
  for my $i (0..$byte_count-1 ) {
      my $byte = $byte_data->[$i];
      $self->serial_port->write(pack('C*', $byte));
      $data = $self->serial_port->read($byte_count+2);
      $hex = $self->serial2hex($data) if $data;
  }
  return $data;
}

sub setup_i2c {    
    my ($self, $args) = @_;
    try { 
	$self->enter_i2c();
	$self->i2c_cfg_pins();
	$self->i2c_set_speed();
    } catch { 
	$self->throw({exception=>'BMP085', error=>$_, message=>'unable to configure/setup bmp085 with the Bus Pirate'});
    }
    return $self;
}

# METHODS
sub enter_binary_mode {
  my ($self) = @_;
  my $count=40;
  my $char="";
  while($count){
      $char= $self->serial_port->read(255); 
      $self->serial_port->write("\x00");
      $self->pause({for=>.02});
      $char = $self->serial_port->read(5); 
      if ($char eq "BBIO1") {
	  $char= $self->serial_port->read(255); #flush buffer
	  $self->io_mode('binary');
	  return 1;
      }
      $count--; 
  }
  return 0;
}

sub exit_binary_mode{
  my ($self, $args) = @_;
  $self->serial_port->write("\x0F");
  $self->io_mode('user');
  return 1;
}

sub send_bus_pirate_cmd {
  my ($self, $args) = @_;
  my ($bb_cmd, $ret_val, $number_of_bytes) = @$args{qw[bb_cmd ret_val bytes]};
  $self->enter_binary_mode unless $self->io_mode eq 'binary';
  $self->pause({for=>.02});
  $self->serial_port->write($bb_cmd); 
  if ($ret_val) {
    my $char= $self->serial_port->read($number_of_bytes); 
    my $tmp = $self->serial_port->read(255); #flush buffer
    $ret_val eq $char ? return 1 : return 0;
  }
  else {
    $@ ? return 0 : return 1;
  }
}

sub reset {
  my ($self, $args) = @_;
  my $success = try { 
    $self->send_bus_pirate_cmd({bb_cmd=>'00000000', ret_val=>'BBIO1'})
  } catch {
    $self->throw({exception=>'BusPirate', error=>$_, message=>'unable to reset bus pirate'});
  };
  $success ? return 1 : return 0;
}

sub switch_bus {
  my ($self, $args) = @_;
  my $mode = $args->{mode};
  my ($cmd, $ret_val) = @{$self->modes->{$mode}};
  my $success = try { 
    $self->send_bus_pirate_cmd({bb_cmd=>$cmd, ret_val=>$ret_val}); 
  } catch {
    $self->throw({message=> "unable to send bus pirate cmd: $cmd"});
  };
  $success ? $self->bus_mode($mode) && return 1 : return 0;
}

# I2C Driver Configuration Methods
sub enter_i2c { 
    $_[0]->send({message=>pack('C*',0x02), delay=>.1}) eq 'I2C1' ? return 1 : return 0; 
}

sub i2c_cfg_pins { 
    $_[0]->send({message=>pack('C*', 0x4c), delay=>.1}) eq "\x01" ? return 1 : return 0; 
}

sub i2c_set_speed {
    my ($self, $args) = @_;
    my $speed = $args->{speed} || '50Khz';
    my $speed_map = {'5Khz' => 0x60,'50Khz' => 0x61,'100Khz' => 0x62,'400Khz' => 0x63};
    my $result_code = $self->send({message=>pack('C*',$speed_map->{$speed}), delay=>.1});  
    "\x01" eq $result_code ? return 1 : return 0; 
}

# METHOD MODIFIERS - Arguement validation and exception handling
around [qw(i2c_bulk_transfer i2c_set_speed i2c_cfg_pins enter_i2c enter_binary_mode exit_binary_mode)] => sub { 
	    my ($method, $self, $args) = @_;
	    my $success;
	    try {
		$success = $self->$method->($args);
		$self->serial2hex($success) == 0x01 ? 
		    return 1 :
		    $self->throw({exception=>'BusPirate', message=>"method: $method returned a error code: $success"});
	    } catch {
		$self->throw({exception=>'BMP085', error=>$_, message=>'Device malfunction'});
	    };
	    return $self;
		
};

around 'send_bus_pirate_cmd' => sub {
  my($method, $self, $args) = @_;
  my ($bb_cmd, $ret_val) = @$args{qw[bb_cmd ret_val]};
  $self->throw({exception=>'InvalidArgs', message=>$args}) unless $bb_cmd && $ret_val;
  my $sucess = try { 
    $self->$method($args); 
  } catch {
    $self->throw({exception=>'BusPirate::Command', error=>$_, message=> "unable to send bus pirate the cmd: $bb_cmd"});
  };
  return $self;
};

around 'switch_bus' => sub {
  my($method, $self, $args) = @_;
  $self->throw({exception=>'InvalidArgs', message=>$args}) unless $args->{mode};
  my $success = try { 
    $self->$method($args); 
  } catch {
    $self->throw({exception=>'BusPirate', error=>$_, message=> "unable to switch bus"});
  };
  $success ? return 1 : return 0;
};

around 'send' => sub {
  my($method, $self, $args) = @_;
  my $message = $args->{message};
  $self->throw({exception=>'InvalidArgs', message=>$args}) unless $message;
  my $response_data = try { 
    $self->$method($args); 
  } catch {
    $self->throw({exception=>'I2C', error=>$_, message=>"unable to send the cmd: $message while in i2c mode"});
  };
  return $response_data;
};

sub _build_modes {
  my ($self, $args) = @_; 
  return {
	  'i2c' => ['\x02', 'I2C1'],
	  'spi' =>['\x01', 'SPI1'],
	  'uart' => ['\x03', 'ART1'],
	  'one_wire' => ['\x04', '1W01'],
	  'binary_raw_wire' => ['\x05', 'RAW1'],
	 };
}

# MODULINO FUNCTION - actualize the synopsis! - Be your own component test
sub run {
  my $bus_pirate = __PACKAGE__->new();

  try { 
    $bus_pirate->enter_binary_mode();
  } catch {
    warn "Counld not enter binary mode\n";
    my $the_fix = $bus_pirate->handle_exception({error=>$_});
    try { $the_fix->() } if ref $the_fix eq 'CODE';
  };

  try {
    $bus_pirate->enter_binary_mode();
    $bus_pirate->switch_bus({mode=>'i2c'});
    my $measurement_data = { units=>'ml', measure=>100.5 };
    $bus_pirate->bus_write({data=>$measurement_data});
    my $response = $bus_pirate->bus_read();
  } catch { 
    $bus_pirate->handle_exception({error=>$_}); 
  };

  try { 
    $bus_pirate->switch_bus({mode=>'spi'}) 
  } catch {
    my $the_fix = $bus_pirate->handle_exception({error=>$_});
    try { $the_fix->() } if ref $the_fix eq 'CODE';
  };
}

run() unless caller;

__PACKAGE__->meta->make_immutable();
no Moose;
1;

__END__

=head1 SYNOPSIS

=over 4

  use Bus::Pirate;
  use Try::Tiny;

  my $bus_pirate = Bus::Pirate->new({file=>'/dev/tty.usbserail-A800KBPV'});

  try { 
    $bus_pirate->enter_binary_mode();
  } catch {
    warn "Counld not enter binary mode\n";
    $bus_pirate->handle_exception({error=>$_});
  };

  try {
    $bus_pirate->enter_binary_mode();
    $bus_pirate->switch_bus({mode=>'i2c'});
    my $measurement_data = { units=>'ml', measure=>100.5 };
    $bus_pirate->bus_write({data=>$measurement_data});
    my $response = $bus_pirate->bus_read();
  } catch { 
    $bus_pirate->handle_exception({error=>$_}); 
  };

  try { 
    $bus_pirate->switch_bus({mode=>'spi'}) 
  } catch {
    $bus_pirate->handle_exception({error=>$_})
  };

=back

=head1 DESCRIPTION

Programmatically access various buses (SPI, I2C, UART, 1WIRE).  Send and recieve data to these buses using a unified interface.  Further provide a framework for adding new buses.  Like the Bus Pirate, this is primary a tool used for design and diagnostic purposes.

=head1 METHODS

=over 4

=item B<< Bus::Pirate->new(%params|$params) >>

This method calls the constructor and provides an instance of the appropriate class. Once the instance is created, it is ready to accept commands so as to control the hardware

=item B<< $object->enter_binary_mode() >>

The bus pirate has two modes of accepting and displaying info one is more friendly for humans reading terminals (user mode) an the other is more conducive to programmatic access (binary bitbanging mode).  This method sets the device to be ready to recieve binary commands from the client

=item B<< $object->exit_binary_mode() >>

Puts the device back into user mode

=item B<< $object->send_bus_pirate_cmd({bb_cmd=>'\x02', ret_val=>{I2C1}) >>

Sends a binary command to the hardware and returns a boolean if the hardware responds with the correct response code

=item B<< $object->$reset() >>

Reset the hardware

=item B<< $object->switch_bus({mode=>'i2c') >>

Change the type of bus the bus pirate is going to use to send and recieve data.

=back

=head1 BUGS

See L<Bus-Pirate/BUGS> for details on reporting bugs.

=head1 AUTHOR

Bus::Pirate is maintained by Matthew Burns

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Matthew Burns

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

