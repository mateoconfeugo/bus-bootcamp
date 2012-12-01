package Bus::Exception::Engine;
use Moose::Role;
use Carp;
use Bus::Exception;
use Try::Tiny;

has dispatch_table => (is=>'rw', isa=>'HashRef[CodeRef]', lazy_build=>1);

sub handle_exception {
    my ($self, $args) = @_;
    my $err = $args->{error};
    my $exception =  $args->{exception} || $err->{exception};
    my $msg = $args->{message} || $err->{message};
    try {
      $exception->throw(error=>$err);
    } catch {
      try { 
	  my $exception_handler = $self->dispatch_table->{$exception};
	  $exception_handler->({message=>$msg, error=>$err});
      } catch {
	die $@;
      };
    };
    return $self;
}

sub get_exception_type {
    my $e = shift;
    my $module = ref $e; 
    my @parts = split '::', $module;
    my $type = $parts[-1];
    return $type;
}

sub default_exception_handler {
    my ($self, $e) = @_;
    warn "ABOUT TO DIE BECAUSE: " . $e->error . "\n";
    die;
}


sub fatal_exception_handler {
    my ($self, $e) = @_;
    warn "FATAL EXCEPTION THROWN: " . $e->error . "\n";
    die;
}

sub log_exception {
    my ( $self, $e ) = @_;
    # Extract the type from the package name minus namespace.
    my $type = get_exception_type($e);
    my $message =  $e->message() ? $e->message() : $e;
    # Build and run query saving the exception into database.
    my ($sec, $min, $hour, $mday, $mon, $year ) = (localtime)[0, 1, 2, 3, 4, 5];
    $hour = sprintf "%02s", $hour;
    $min = sprintf "%02s", $min;
    $sec = sprintf "%02s", $sec;
    $mday = sprintf "%02s", $mday;
    $mon++;
    $mon = sprintf "%02s", $mon;
    $year += 1900;
    my $date_time = $year . $mon . $mday . $hour . $min . $sec;
    my @params = ($e->job_id, $e->fid, $type, $date_time, $message);
    use Data::Dumper;
    warn Dumper(\@params);
    return $self;
}

sub _build_dispatch_table {
    my ($self, $args) = @_;

    # Ensure all exceptions are objects.
    local $SIG{__DIE__} = sub {
	my $err = shift;
	if (my  $e = Exception::Class->caught('Exception::Class') ) {
	    die $err; # re-throw
	}
	else {
	    BusException->throw(message => $err);
	  }
    };

    my $dt = {
	      Base => sub { $self->default_exception_handler($_[0]) },
	      I2C => sub { $self->default_exception_handler($_[0]) },
	      SPI => sub { $self->default_exception_handler($_[0]) },
	      Monitorying =>  sub { $self->default_exception_handler($_[0]) },
	     };
    return $dt;
}

no Moose;
1;

__END__

# ABSTRACT: Handling the exceptions the bus pirate throws

=pod

=head1 NAME

Bus::Exception::Engine - Exception Handling Engine for the Bus Pirate.

=head1 VERSION

version 0.0.1

=head1 DESCRIPTION

This role allows for arbitrarily complex exception handling logic and along with Exception Class tries not add to much exception code that gets in the way of what you are doing.  This part of a larger framework for handling exceptions using idiom that take advantage of some moose feature.  The idea is to make it easy to throw and catch exceptions yet not obscure the normative operation.

=head1 Methos

=over 4

=item B<< $obj->handle_exception(Bus::Exception::SPI->new())   >>

This is a dispatch function that uses the type of exception to decided what handler to use.

=item B<< Bus::Exception::I2C() throw_i2c >>

Errors and exceptions relating to the i2c data bus


=item B<< Bus::Exception::SPI() throw_spi >>

Errors and exceptions relating to the spi data bus


=item B<< Bus::Exception::UART() throw_uart >>

Errors and exceptions relating to the spi data bus

=back

=head1 BUGS

See L<Bus-Pirate/BUGS> for details on reporting bugs.

=head1 AUTHOR

Bus::Pirate is maintained by Matt Burns

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Matthew Burns

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

