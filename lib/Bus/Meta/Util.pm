package Bus::Meta::Util;
# ABSTRACT: Convience functions to make figuring out what methods are available to objects using roles
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

