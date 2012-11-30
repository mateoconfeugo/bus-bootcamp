package Bus::Exception;
use Exception::Class (
		      'InvalidArgs' => { 
					description => 'invalid method parameter(s)'
				       },
		      'BusPirate' => { 
				      description => 'Generic Bus Pirate exception';
				     },
		      'I2C' => { 
				isa => 'BusPirate',
				description  => 'i2c bus error'
			       },
		      'SPI' => {
				isa => 'BusPirate',
				description => 'These exceptions are related to problems with spi bus',
					},
		      'Monitoring' => {
				       fields => [ 'data', 'path' ],
				       description => 'problems with diagnostic channels'
				      },
		     );
1;
__END__

# ABSTRACT: Errors and Exceptions produced when using the Bus Pirate 

=pod

=head1 NAME

Bus::Exception - Exceptions the Bus Pirate throws

=head1 VERSION

version 0.0.1

=head1 DESCRIPTION

There is always the possiblity when dealing with I/O that the resource might not respond correctly or at all.  Applications can have truly exception circumstances such there is nothing attached to the bus.  Errors also will be represented as exceptions and are part of a larger overall exception handling system the Bus::Pirate uses.

=head1 EXCEPTIONS

=over 4

=item B<< Bus::Exception::Generic()  throw_bus() >>

This is a default catch all error hopefully in due time it will be eleminated

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
