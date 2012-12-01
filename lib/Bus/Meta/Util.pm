package Bus::Meta::Util;
use Moose::Role;

sub methods {
    my ($self, $args) = @_;
    my @list =  map {  $_->fully_qualified_name} $self->meta->get_all_methods;
    return \@list;
}

sub attributes {
    my ($self, $args) = @_;
    my @list = map {  $_->name }  $self->meta->get_all_attributes;
    return \@list;
}

no Moose;
1;

