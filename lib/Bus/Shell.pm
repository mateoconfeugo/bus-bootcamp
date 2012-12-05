package Bus::Shell;
use Moose::Role;
use Devel::REPL;
use Term::Shell;

has repl => (
	     is=>'rw',
	     lazy_build=>1
	    );

has term_shell => (
		   is=>'rw',
		   lazy_build=>1
		  );

sub _build_term_shell {
  my ($self) = @_;
  my $shell =  Term::Shell->new({repl=>$self->repl});
  return $shell;
}

sub _build_repl_shell {
  return Devel::REPL->new();
}

sub run_repl  { 
  my ($self) = @_;
  print "command 1!\n"; 
  $self->repl->run();
}

sub smry_repl { "Interactive universal bus interface shell" }

sub help_repl{
  <<'END';
    Help on 'repl', the interactive universal bus interface
END
}

sub run_scan_bus  { 
  my ($self) = @_;
  print "command 1!\n"; 
  $self->run();
}

sub run_diagnostic { "Gives you the devices attached to the bus" }

sub help_diagnostic{
  <<'END';
    Help on 'diagnostic', the interactive universal bus interface diagnostic
END
}

no Moose;
1;
