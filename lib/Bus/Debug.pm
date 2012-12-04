# ABSTRACT: place holder
package Bus::Debug;
use Moose::Role;

sub _build_debug {
  $ENV{BC_BUS_DEBUG} ? return 1 : 0;
}

no Moose;
1;
