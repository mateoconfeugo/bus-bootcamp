package Bus::Math;
use Moose::Role;
# ABSTRACT: Math common to manipulating buses and the  data on them

use constant SETIN => 0x40; #set pin direction input(1) output (0), returns read
use constant SETON => 0x80; #set pins on (1), returns read
# Bits are assigned as such:

use constant MOSI => 0x01;
use constant CLK => 0x02;
use constant MISO => 0x04;
use constant CS => 0x08;
use constant AUX => 0x10;
use constant PULLUP => 0x20;
use constant POWER => 0x40;



sub leach {
    my ($self, $args) = @_;
    my $bpcommand= (SETIN | AUX ); 
    my $bpcommand = ( SETON | POWER | PULLUP | CS | MISO | CLK | MOSI);

    open FH, ">", "/Users/matthewburns/github/testingbin" or die "unable to open testingbin $!";
    binmode FH;
    foreach (1,2,3,4,5,6,7,8,9)
    {
	my $buf = chr($_);
	syswrite FH,$buf;
    }
    close FH;
}

sub hex2serial { 
    my ($self, $num) = @_;
    pack('C*', $num) };

sub serial2hex { 
    my ($self, $num) = @_;
    return $self->dec2hex(unpack('C*', $num)) 
}

sub dec2bin {
    my ($self, $num) = @_;
    my $str = unpack("B32", pack("N", $num));
    $str =~ s/^0{24}(\d)/$1/;
#    $str =~ s/0^+(?=\d)//; # remove leading zeros
    return $str;
}

sub bin2dec { 
    my ($self, $num) = @_;
    return unpack("N", pack("B32", substr("0" x 32 . $num, -32))) 
}

sub hex2bin { 
    my ($self, $num) = @_;
    return $self->dec2bin(hex($num)) 
}

sub bin2hex { 
    my ($self, $num) = @_;
    return sprintf('%02X', ord($num)) 
}

sub dec2hex { 
    my ($self, $num) = @_;
    return sprintf("%x", $num);
}

no Moose;
1;
