package Bus::BC;
# ABSTRACT: Module for developing and  testing the various types of buses used in an embedded environment
use Moose;

has master => (is=>'rw', isa=>'Str', required=>1);
has tx_bus => (is=>'rw', isa=>'Str', required=>1);
has rx_bus => (is=>'rw', isa=>'Str', required=>1);
has bus_driver_map => (is=>'rw', isa=>'HashRef', lazy_build=>1);
has test_data => (is=>'rw', isa=>'HashRef', lazy_build=>1);

sub echo_test {
  my ($self) = @_;
  my $msg = "The " . $self-> master . " is the master, sending on: " .
    $self->tx_bus . " and recieving on: " . $self->rx_bus . "\n";
  warn $msg;
  $self->prepare_client if $self->master eq 'target';
  $self->prepare_host();
  $self->send({msg=>$self->test_data});
}

sub prepare_client {
  my ($self) = @_;
}

sub prepare_host {
  my ($self) = @_;
}

sub send {
  my ($self, $args) = @_;
  my $msg_data = $args->{msg};
#  my $path = $self->bus_driver_map->{$self->tx_bus};
#  open my $fh, ">",  $path or die "could not open file: $path $@\n";
#  print $fh $msg_data;
}

sub _build_bus_driver_map {
  my $self = shift;
  return {};
}

sub _build_test_data {
  my $self = shift;
  return {
	  source => $self->master,
	  tx_bus => $self->tx_bus,
	  rx_bus => $self->rx_bus,
	  ts => time,
	 };
}

__PACKAGE__->meta->make_immutable();
no Moose;
1;
