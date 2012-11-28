package Bus::Serial;
use Moose::Role;
use Device::SerialPort qw( :PARAM :STAT 0.07 );
use Time::HiRes qw (sleep);
use Bus::Exception qw(throw_bus);

has serial_port => (is=>'rw', required=>1, lazy_build=>1);
has port_filepath => (is=>'rw', lazy_build=>1);

sub _build_serial_port {
  my ($self, $args) = @_;
  my $port_filepath = $self->port_filepath;
  my $quiet = 1;
  my $port = Device::SerialPort->new($port_filepath, $quiet) ||  Bus::Exception::Generic->throw(error=>$!);
  $port->databits(8);
  $port->baudrate(115200);
  $port->parity("none");
  $port->stopbits(1);
  # Poll to see if any data is coming in
  sleep (.02 );
  my $char = $port->lookfor();
  return $port;
}

no Moose;
1;
