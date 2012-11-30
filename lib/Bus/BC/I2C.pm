package Bus::BC::I2C;
use Moose::Role;

sub read {
    my ($self) = @_;
}

sub write {
    my ($self) = @_;
}

sub send_start_bit {
    my ($self) = @_;
    $self->serial_port->write("\x02");
    select(undef,undef,undef, .02);
    return self.response();
}

sub send_stop_bit {
    my ($self) = @_;
    $self->serial_port->write("\x03");
    select(undef,undef,undef, .02); 
    return self.response();
}

sub read_byte { 
    my ($self) = @_:
    $self->serial_port->write("\x04");
    select(undef,undef,undef, .02); 
    return self.response(1, True);
}

sub  send_ack {
    my ($self) = @_;
    $self->serial_port->write("\x06");
    select(undef,undef,undef, .02); 
    return self.response();
}

sub send_nack {
    my ($self) = @_;
    $self->serial_port->write("\x07");
    select(undef,undef,undef, .02);
    return self.response();
}

sub start_sniffer {
    my ($self) = @_;
    $self->serial_port->write("\x0F");
    pause({for=>.02});
}

sub write_register {
  my ($self, $register, $value) = @_;
 # write 0x2E into register 0xf4 and wait for 4.5milliseconds
  pause({for=>4.5, units=>'ms'});
  #
  # [0xee 0xac [0xef r]
  # [$write_address, $read_address, 
}

sub read_register {
  my ($self, $register) = @_;
}

no Moose;
1;
