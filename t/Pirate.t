use Test::Routine;
use Test::Routine::Util;
use Test::More;
use Test::Exception;
use Bus::Pirate;

has bp => (is=>'rw', isa=>'Bus::Pirate', lazy_build=>1);

test 'changing operational modes' => sub {
  my ($self) = @_;
  plan tests => 4;

  my $pirate = $self->bp;
  lives_and { 
    my $ret_val = $pirate->enter_binary_mode;
    is(1, $ret_val) } 'bus pirate entered binary mode';

  lives_and { 
    my $ret_val = $pirate->exit_binary_mode;
    is(1, $ret_val) } 'bus pirate exited binary mode';
  # change the port path to something incorrect
  $pirate = Bus::Pirate->new({port_filepath=> '/foo'});
  throws_ok { 
    $pirate->enter_binary_mode();
    my $ph = 'ham';
  } 'Bus::Exception::Generic';
  
  throws_ok { 
    $pirate->exit_binary_mode();
    my $ph = 'ham';
  } 'Bus::Exception::Generic';
};

test 'sending control commands to the bus pirate' => sub {
  my ($self) = @_;
  plan tests => 2;
  my $cmd = '\x02';
  my $ret_val = 'I2C1';
  my $pirate = $self->bp;
  lives_and { 
    my $result =$pirate->send_bus_pirate_cmd({bb_cmd=>$cmd, ret_val=>$ret_val, bytes=>4});
    is($result, $ret_val) } 'bus sent control command';
  # change the port path to something incorrect
  $pirate = Bus::Pirate->new({port_filepath=> '/foo'});
  dies_okay { 
    $pirate->switch_bus({mode=>'spi'}) } 'exception thrown as it should';
};

test 'switching the type of data bus ' => sub {
  my ($self) = @_;
  plan tests => 2;
  $self->bp->enter_binary_mode();
  my $ret_val = 'I2C1';
  my $cmd = 'i2c';
  my $hex_cmd = '\x02';
  lives_and { 
    my $result =$self->bp->switch_bus({mode=>'i2c'});
    is($result, $ret_val) } 'bus switch control command';
  # change the port path to something incorrect
  dies_okay { $self->bp->send_bus_pirate_cmd({bb_cmd=>$hex_cmd, ret_val=>$ret_val, bytes=>4}) } 'exception thrown as it should';
};


test 'resetting the bus pirate' => sub {
  my ($self) = @_;
  plan tests => 2;
  lives_and { is(1, $self->bp->reset()) } 'reset bus pirate';
  # change the port path to something incorrect
  dies_okay { $self->bp->reset() } 'exception thrown as it should';
};

sub _build_bp {
  my $self = shift;
  return Bus::Pirate->new({port_filepath=>'/dev/tty.usbserial-A800KBPV'});
}

run_me();
done_testing();
1;
