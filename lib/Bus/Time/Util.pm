package Bus::Time::Util;
use Moose::Role;

sub pause {
  my $args = @_;
  my $duration = $args->{for} || .02;
  my $units = $args->{units) || 'ms';
  select(undef,undef,undef, .02) if $units eq 'ms';
}

no Moose;
1;
