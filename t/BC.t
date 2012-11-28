use Test::Routine;
use Test::Routine::Util;
use Test::More;
use Set::CrossProduct;
use Bus::BC;

test 'all possible combinations doing the echo test' => sub {
  my @tx_buses = (qw[uart i2c spi can usb ethernet]);
  my @rx_buses = (qw[uart i2c spi can usb ethernet]);
  my @master = (qw[host target]);
  my $opts = [\@master, \@tx_buses, \@rx_buses];
  my $iterator = Set::CrossProduct->new($opts);
  plan tests => $iterator->cardinality;

  while( my $args = $iterator->get() ) {
    my $obj = Bus::BC->new({master=>$args->[0], tx_bus=>$args->[1], rx_bus=>$args->[2]});
    my $rx_data = $obj->echo_test();
    is($rx_data, $obj->test_data, "Data sucessfully sent");
  }
};

run_me();
done_testing();
1;
