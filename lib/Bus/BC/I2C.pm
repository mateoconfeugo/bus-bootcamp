package Bus::BC::I2C;
use Moose::Role;

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
    select(undef,undef,undef, .02); #sleep for fraction of second for data to arrive #sleep(1);
}

sub control_register {
  my ($self, $register, $value) = @_;
  #
  # [0xee 0xac [0xef r]
  # [$write_address, $read_address, 
}

sub get_register {
  my ($self, $register) = @_;
}

no Moose;
1;
