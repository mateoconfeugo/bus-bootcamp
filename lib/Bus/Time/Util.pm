package Bus::Time::Util;
# ABSTRACT: Time Data related methods in relation to bus domain.
use Moose::Role;

sub pause {
  my $args = shift;
  my $duration = $args->{for} || .02;
  my $units = $args->{units} || 'ms';
  select(undef,undef,undef, .02) if $units eq 'ms';
}

no Moose;
1;
