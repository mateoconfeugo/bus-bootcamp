package Bus::I2C;
# DEPENDENCIES
use Moose::Role;
use Moose::Util qw(apply_all_roles);

# ROLES
with qw(Throwable);              # throw method
with 'Bus::Serial';
with 'Bus::Time::Util';

requires 'send';
#requires 'i2c_bulk_transfer';

# METHODS
# Configuration Methods
sub enter_i2c { 
    my ($self, $args) = @_;
    $self->send({message=>"\x02", delay=>.1}) eq 'I2C1' ? return 1 : return 0; 
}

sub i2c_cfg_pins {
    my ($self, $args) = @_;
    "\x01" eq  $self->send({message=>"\x4c", delay=>.1}) ? return 1 : return 0; 
}

sub i2c_set_speed {
    my ($self, $args) = @_;
    my $speed = $args->{speed} || '50Khz';
    my $speed_map = {
	'5Khz' => "\x60",
	'50Khz' => "\x61",
	'100Khz' => "\x62",
	'400Khz' => "\x63"
    };
    "\x01" eq $self->send({message=>$speed_map->{$speed}, delay=>.1})  ? return 1 : return 0; 
}

# Control Methods
sub i2c_send_start_bit {  $_[0]->send({message=>"\x02"}) }
sub i2c_send_stop_bit {   $_[0]->send({message=>"\x03"}) }
sub i2c_read_byte {       $_[0]->send({message=>"\x04"}) }
sub i2c_send_ack {        $_[0]->send({message=>"\x06"}) }
sub i2c_send_nack {       $_[0]->send({message=>"\x07"}) }
sub i2c_start_sniffer {   $_[0]->send({message=>"\x0F"}) }

# Byte Level Data Setting and gettings methods


sub i2c_command {
  my ($self, $args) = @_;
  my ($i2c_addr, $cmd) = @$args{qw[i2c_addr cmd]};
  $self->i2c_send_start_bit();
  my $data = $self->i2c_bulk_transfer({data=>[$i2c_addr<<1, $cmd]});
  $self->i2c_send_stop_bit();
  return $data;
}

sub i2c_get_byte {
  my ($self, $args) = @_;
  my ($i2c_addr, $addr) = @$args{qw[i2c_addr addr]};
  $self->i2c_send_start_bit();
  my $data = $self->i2c_bulk_transfer({data=>[$i2c_addr << 1, $addr]});
  $self->i2c_send_start_bit();
  $data += $self->i2c_bulk_transfer({data=>[$i2c_addr << 1 | 1]});
  my $byte = $self->i2c_read_byte();
  $self->i2c_send_nack();
  $self->i2c_send_stop_bit();
  return $byte;
}

sub i2c_set_byte {
 my ($self, $args) = @_;
 my $i2c_addr = $args->{i2c_addr};
 my $addr = $args->{addr};
 my $val = $args->{value};
 $self->i2c_send_start_bit();
 my $status = $self->i2c_bulk_transfer(3, [$i2c_addr<<1, $addr, $val]);
 $self->i2c_send_stop_bit();
 $self->throw({exception=>'IOError', messsage=>"I2C command on address 0x%02x not acknowledged!"}) unless $status =~ /x01/ == -1;
}

sub  i2c_set_word {
  my ($self,  $args) = @_;
  my ($i2c_addr, $addr, $val) = @$args{qw[i2c_addr addr val]};
  my $vh = $val/256;
  my $vl = $val%256;
  $self->i2c_send_start_bit();
  my $word = $self->i2c_bulk_transfer(4, [$i2c_addr << 1, $addr, $vh, $vl]);
  $self->i2c_send_stop_bit();
  return $word;
}

# Reads two byte value (big-endian) from address addr 
sub i2c_get_word {
  my ($self,  $args) = @_;
  my ($i2c_addr, $addr, $cmd) = @$args{qw[i2c_addr addr val]};
  $self->i2c_send_start_bit();
  my $data = $self->i2c_bulk_transfer(2, [$i2c_addr << 1, $addr]);
  $self->i2c_send_start_bit();
  $data += $self->i2c_bulk_transfer(1, [$i2c_addr << 1 | 1]);
  my $rh = $self->i2c_read_byte();;
  $self->i2c_send_ack();
  my $rl = $self->i2c_read_byte();
  $self->i2c_send_nack();
  $self->i2c_send_stop_bit();
  return (($rh << 8) + $rl);
}

around 'i2c_get_byte' => sub {
  my ($method, $self, $args) = @_;
  my ($i2c_addr, $addr) = @$args{qw[i2c_addr addr]};
  $self->throw({exception=>'InvalidArgs', error=>$args, message=>$args}) unless $i2c_addr && $addr;
  my $byte = $self->$method($args);
  $self->throw({exception=>'IOError', messsage=>"unable to get byte at address $addr"}) unless $byte =~ /x01/ == -1;
  $self->log_debug("Data at $i2c_addr: $byte");
  return $byte;
};

around 'i2c_set_word' => sub {
  my ($method, $self, $args) = @_;
  my ($i2c_addr, $addr, $val) = @$args{qw[i2c_addr addr val]};
  $self->throw({exception=>'InvalidArgs', error=>$args, message=>$args}) unless $i2c_addr && $val;
  my $word = $self->$method($args);
  $self->throw({exception=>'IOError', messsage=>"unable to set word to value: $val"}) unless $word =~ /x01/ == -1;
  $self->log_debug("set word $word at address $addr to $val");
  return $word;
};

around 'i2c_get_word' => sub {
  my ($method, $self, $args) = @_;
  my ($i2c_addr, $addr, $val) = @$args{qw[i2c_addr addr val]};
  $self->throw({exception=>'InvalidArgs', error=>$args, message=>$args}) unless $i2c_addr && $addr;
  my $word = $self->$method($args);
  $self->throw({exception=>'IOError', messsage=>"unable to get word at address: $addr instead got $word"}) unless $word =~ /x01/ == -1;
  $self->log_debug("retrieved word $word from address $addr");
  return $word;
};

around 'i2c_command' => sub {
  my ($method, $self, $args) = @_;
  my ($i2c_addr, $cmd) = @$args{qw[i2c_addr cmd]};
  $self->throw({exception=>'InvalidArgs', error=>$args, message=>$args}) unless $i2c_addr && $cmd;
  my $results = $self->$method($args);
  $self->throw({exception=>'IOError', messsage=>"I2C command $cmd on address $i2c_addr not acknowledged!"}) if $results-> [0] == 0x01;
  $self->log_debug("Data retrieved for command: $cmd");
  return $results;
};

no Moose;
1;

__END__

# ABSTRACT: Moose::Role for talking to I2C enabled hardware via the  Bus Pirate;

=pod

=head1 NAME

Bus::I2C - Moose::Role for talking to I2C enabled hardware via the  Bus Pirate;

=head1 VERSION

version 0.0.1

=head1 DESCRIPTION

Compose this role into the object representing the i2c enabled hardware

=head1 CONSUMES ROLES

=over 4

=item B<< Bus::Serial >>

=item B<< Bus::Time::Util >>

=back


=head1 METHODS

=over 4

=item B<< $object->enter_i2c() >>

# Put the Bus Pirate into I2C Bus mode

=item B<< $object->i2c_send_start_bit() >>

Control method sending signal to tell the device to get ready for a command;

=item B<< $object->i2c_send_stop_bit() >>

Control method sending signal to tell the device the command is done being sent

=item B<< $object->i2c_$read_byte() >>

Read a byte from the i2c the hardware;

=item B<< $object->i2c_send_ack >>

acknowledge a signal from hardware

=item B<< $object->i2c_send_nack >>

do not acknowledge a signal from hardware

=item B<< $object->i2c_sniffer >>

search for hardware on the i2c bus

=item B<< $object->i2c_get_byte >>

reads a  byte at a specific address in the hardware used for obtaining values from the device;


=item B<< $object->i2c_set_byte >>

writes a  byte at a specific address in the hardware. Used for setting device values. 

=item B<< $object->i2c_set_byte >>

writes a  byte at a specific address in the hardware. Used for setting device values. 

=item B<< $object->i2c_command >>

Writes one byte command to slave 

=item B<< $object->i2c_set_word >>

Writes two byte value (big-endian) to address addr 

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
