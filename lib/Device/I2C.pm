package Device::I2C;
# ABSTRACT: Interface to I2C via the dev-i2c device driver ioctrls 
use Moose;
use IO::File;
use Fcntl;
use MooseX::Types::Path::Class;

use Inline(
    C => Config => INC => '-I/usr/local/include',
    AUTO_INCLUDE => '#include <linux/i2c.h>
            #include <linux/i2c-dev.h>',
    CCFLAGS => '-O2',    # necessary for inline functions
);

use Inline C => 'DATA' => NAME => 'Device::I2C',  VERSION => $Device::I2C::VERSION;
use constant I2C_SLAVE => 0x0703;

has file => (is=>'rw', isa=>'Path::Class::File', required=>1, coerce=>1);
has device => (is=>'rw', isa=>'FileHandle', lazy_build=>1);
has fileno => (is=>'rw', isa=>'Int', lazy_build=>1);
has last_device => (is=>'rw', isa=>'Int', defaults=>-1);

sub _build_device {
    my $self = shift;
    my $path = $self->file->absolute;
    my $fh = try {
	$self->file->open(O_RDWR);
    } catch {
	$self->throw({exception=>'IO', error=>$_, message=>"I2C-dev error: unable to open device file: $path"});
    };
    return $fh;
}

sub _build_fileno {
    my $self = shift;
    return $self->device->fileno;
}

sub DESTROY {
    my $self = shift;
    $self->device->close();
}

sub select_device {
    my ($self, $args) = @_;
    my $dev_number  = $args->{device_number};
    my $old_dev = $self->fileno;
    $self->last_device($dev_number);
    $old_dev != $dev_number
	? $self->device->ioctl(I2C_SLAVE, $dev_number) 
	: 1;
}

# return (data, errno) in array context,
# or just data (-1 for error).
sub read_word_data {
    my ($self, $args)  = @_;
    my $cmd = $args->{cmd};
    my $retval = _read_word_data($self->fileno, $cmd);
    return wantarray 
	? ( $retval, (( $retval == -1 ) ? $! : 0)) 
	: $retval;
}

sub write_word_data {
    my ($self, $args) = @_;
    my ($cmd, $value) = @$args{(qw[cmd value)])};
    return _write_word_data($self->fileno, $cmd, $value);
}

sub read_block_data {
    my ($self, $args) = @_;
    my $cmd    = $args->{cmd};
    my $data   = ' ' x 32;
    my $retval = _read_block_data($self->fileno, $cmd, $data);
    return ( $retval < 0 ) ? undef: $data;
}

sub run {
    my $obj = __PACKAGE__->new({file='/dev/i2c/'});
}

run() unless caller;

1;

__DATA__

__C__

int _write_quick(int file, int value)
{
    return i2c_smbus_write_quick(file, value);
}

int _read_byte(int file)
{
    return i2c_smbus_read_byte(file);
}

int _write_byte(int file, int value)
{
    return i2c_smbus_write_byte(file, value);
}

int _read_byte_data(int file, int command)
{
    return i2c_smbus_read_byte_data(file, command);
}

int _write_byte_data(int file, int command, int value)
{
    return i2c_smbus_write_byte_data(file, command, value);
}

int _read_word_data(int file, int command)
{
    return i2c_smbus_read_word_data(file, command);
}

int _write_word_data(int file, int command, int value)
{
    return i2c_smbus_write_word_data(file, command, value);
}

int _process_call(int file, int command, int value)
{
    return i2c_smbus_process_call(file, command, value);
}

int _read_block_data(int file, int command, SV* output)
{
    char buf[ 32 ];
    int retval;
    retval = i2c_smbus_read_block_data(file, command, buf);
    if (retval == -1)
        return retval;
    sv_setpvn(output, buf, retval);
    return retval;
}

int _write_block_data(int file, int command, SV* value)
{
    STRLEN len;
    char *buf = SvPV(value, len);
    return i2c_smbus_write_block_data(file, command, len, buf);
}

int _write_i2c_blockdata(int file, int command, SV* value)
{
    STRLEN len;
    char *buf = SvPV(value, len);
    return i2c_smbus_write_i2c_block_data(file, command, len, buf);
}

=pod

=head1 SYNOPSIS

  use Device::I2C;

  my $i2c_bus = Device::I2C->new({file=>'/dev/i2c-0'});
  $i2c_bus->selectDevice({device_number => $device_number );
  my $data = $i2c_bus->read_word_data( $command );
  $i2c_bus->write_word_data( $command, $data );


=head1 DESCRIPTION

This provides a thin Moosified wrapper for the Linux I2C and SMBus ioctls.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Thanks to original author Ned Konz as I found this code on the perl monks and simply moosified it

L<Inline>

L<perl>

=cut
