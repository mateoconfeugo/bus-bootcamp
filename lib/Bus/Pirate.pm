package Bus::Pirate;
use Moose;
use Moose::Util::TypeConstraints;
use Exception::Class qw(Bus::Exception::Generic throw_bus);

with qw(Bus::BC::I2C);
with qw(Bus::Serial);
with qw(Bus::Debug);
with qw(Bus::Exception::Engine);

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

has io_mode => (is=>'rw', isa=> enum([qw(binary user)]) );
has bus_mode => (is=>'rw', isa=> enum([qw(i2c spi uart 1wire)]) );
has modes => (is=>'rw', isa=>'HashRef', lazy_build=>1);

around 'enter_binary_mode' => sub {
  my($orig, $self, $args) = @_;
  my $ret_val = eval { $self->$orig($args) };
  my $e = Exception::Class->caught();
  $e->rethrow(message=>'foo') if $e;
  return $ret_val;
};

sub enter_binary_mode {
  my ($self) = @_;
  my $count=40;
  my $char="";
  while($count){
      $char= $self->serial_port->read(255); 
      $self->serial_port->write("\x00");
#    Bus::Exception::Generic->throw(error=>$!) if $!;
      select(undef,undef,undef, .02); #sleep for fraction of second for data to arrive #sleep(1);
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

around 'exit_binary_mode' => sub {
  my($orig, $self, $args) = @_;
  my $ret_val = eval { $self->$orig($args) };
  my $e = Exception::Class->caught();
  $e->rethrow if $e;
  return $ret_val;
};

sub exit_binary_mode{
  my ($self, $args) = @_;
  my $is_in_binary_mode =  $self->enter_binary_mode; #return to BBIO mode (0x00), (should get BBIOx)
  $self->serial_port->write("\x0F")  if $is_in_binary_mode;
  $self->io_mode('user');
  return $is_in_binary_mode;
}

around 'send_bus_pirate_cmd' => sub {
  my($orig, $self, $args) = @_;
  my ($bb_cmd, $ret_val) = @$args{qw[bb_cmd ret_val]};
#  throw_args(msg=>$args) unless $bb_cmd && $ret_val;
  my $result = eval { $self->$orig($args) };
  my $e = Exception::Class->caught();
  $e->rethrow if $e;
  return $result;
};

sub send_bus_pirate_cmd {
  my ($self, $args) = @_;
  $self->enter_binary_mode; # unless $self->io_mode eq 'binary';
  my ($bb_cmd, $ret_val, $number_of_bytes) = @$args{qw[bb_cmd ret_val bytes]};
  select(undef,undef,undef, .02); #sleep for fraction of second for data to arrive #sleep(1);
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
  my $result = eval { $self->send_bus_pirate_cmd({bb_cmd=>'00000000', ret_val=>'BBIO1'}) };
  throw_bus() if $@;
  $result ? return 1 : return 0;
}

# Handle preconditions and exception logic around changing a bus
around 'switch_bus' => sub {
  my($orig, $self, $args) = @_;
  die "must provide a mode" unless $args->{mode};
  my $ret_val = $self->$orig($args);
  my $e = Exception::Class->caught();
  $e->rethrow if $e;
  return $ret_val;
};

sub switch_bus {
  my ($self, $args) = @_;
  my $mode = $args->{mode};
  my ($cmd, $ret_val) = @{$self->modes->{$mode}};
  my $result = eval { $self->send_bus_pirate_cmd({bb_cmd=>$cmd, ret_val=>$ret_val}) };
  $self->bus_mode($mode) if $result;
  $result ? return 1 : return 0;
}

sub _build_modes {
  my ($self, $args) = @_; 
  return {
	  i2c => ['\x02', 'I2C1'],
	  spi =>['\x01', 'SPI1'],
	  uart => ['\x03', 'ART1'],
	  'one_wire' => ['\x04', '1W01'],
	  'binary_raw_wire' => ['\x05', 'RAW1'],
	 };
}

sub run {
  my $obj = __PACKAGE__->new();
  warn "Counld not enter binary mode\n" unless eval { $obj->enter_binary_mode() };

  eval {
    $obj->enter_binary_mode();
    $obj->switch_bus({mode=>'i2c'});
    my $measurement = { units=>'ml', measure=>100.5 };
    $obj->bus_write({data=>$measurement});
    my $response = $obj->bus_read() 
  };

  $obj->handle_exception if $@;

  eval { $obj->switch_bus({mode=>'spi'}) };
  $obj->handle_exception if $@;
}

run() unless caller;

__PACKAGE__->meta->make_immutable();
no Moose;
1;

__END__

# ABSTRACT: Perl Wrapper around the Bus Pirate hardware 


=pod

=head1 NAME

Bus::Pirate- The way perl apps access the hardware resource for testing various types of data bus commonly used with micro controllers.

=head1 VERSION

version 0.0.1

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

Bus::Pirate is maintained by Matt Burns

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Matthew Burns

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

