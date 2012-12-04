package Bus::Math;
use Moose::Role;
# ABSTRACT: Math common to manipulating buses and the  data on them
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
