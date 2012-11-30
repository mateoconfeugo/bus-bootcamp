package Bus::Serial;
use Moose::Role;
use Device::SerialPort qw( :PARAM :STAT 0.07 );
use Time::HiRes qw (sleep);
use Bus::Exception qw(throw_bus);
use MooseX::Types::Path::Class;

with 'Bus::Time::Util';

has serial_port => (is=>'rw', required=>1, lazy_build=>1, handles=>['response']);
has file => (is=>'rw', isa=>'Path::Class::File', required=>1, coerce=>1);
has stall_default => (is=>'ro', isa=>'Int', default=>10);
has timeout => (is=>'ro', isa=>'Int', default=>10);

sub response {
  my ($self, $args) = @_;
  my($count, $char_data) = $self->serial_port->read(255);
  my $chars=0;
  my $buffer="";
  while ($self->timeout > 0) {
       my ($count,$saw) = $port->read(255); # will read _up to_ 255 chars
       if ($count > 0) {
               $chars+=$count;
               $buffer.=$saw;
       }
       else {
               $timeout--;
       }
     }
  return $buffer;
}

sub bulk_transfer {
  my ($self, $args) = @_;
  my $byte_count = $args->{byte_count} || 1;  
  my $byte_string = $args->{byte_string} || 'None';
  return if $byte_string eq 'None';
  $self->serial_port->write(("\x10" | ($byte_count-1)));
  for my $bit(0..$byte_count) {
    $self->serial_port->write(byte_string[i]);
    my $data = $self->response($byte_count+1);
  }
  return $data->[1];
}

sub _build_serial_port {
  my ($self, $args) = @_;
  my $port_filepath = $self->file;
  my $quiet = 1;
  my $port = Device::SerialPort->new($port_filepath, $quiet) ||  Bus::Exception::Generic->throw(error=>$!);
  $port->databits(8);
  $port->baudrate(115200);
  $port->parity("none");
  $port->stopbits(1);
  $port->read_char_time(0);     # don't wait for each character
  $port->read_const_time(1000); # 1 second per unfulfilled "read" call
  # Poll to see if any data is coming in
  pause({for=>.02});
  my $char = $port->lookfor();
  return $port;
}

no Moose;
1;
