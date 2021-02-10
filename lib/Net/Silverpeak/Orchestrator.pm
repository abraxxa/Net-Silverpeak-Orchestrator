package Net::Silverpeak::Orchestrator;

# ABSTRACT: Silverpeak Orchestrator REST API client library

use 5.024;
use Moo;
use feature 'signatures';
use Types::Standard qw( Str );
use Carp qw( croak );
use HTTP::CookieJar;
use List::Util qw( any );
# use Data::Dumper::Concise;

no warnings "experimental::signatures";

=head1 SYNOPSIS

    use strict;
    use warnings;
    use Net::Silverpeak::Orchestrator;

    my $orchestrator = Net::Silverpeak::Orchestrator->new(
        server      => 'https://orchestrator.example.com',
        user        => 'username',
        passwd      => '$password',
        clientattrs => { timeout => 30 },
    );

    $orchestrator->login;

=head1 DESCRIPTION

This module is a client library for the Silverpeak Orchestrator REST API.
Currently it is developed and tested against version 9.0.2.

=cut

has 'user' => (
    isa => Str,
    is  => 'rw',
);
has 'passwd' => (
    isa => Str,
    is  => 'rw',
);

with 'Role::REST::Client';

sub _build_user_agent ($self) {
    require HTTP::Thin;
    return HTTP::Thin->new(
        %{$self->clientattrs},
        cookie_jar => HTTP::CookieJar->new
    );
}

sub _error_handler ($self, $res) {
    my $error_message = $res->data;

    croak('error (' . $res->code . '): ' . $error_message);
}

=method login

Logs into the Silverpeak Orchestrator.

=cut

sub login($self) {
    my $res = $self->post('/gms/rest/authentication/login', {
        user     => $self->user,
        password => $self->passwd,
    });

    $self->_error_handler($res)
        unless $res->code == 200;

    return 1;
}

=method logout

Logs out of the Silverpeak Orchestrator.

=cut

sub logout($self) {
    my $res = $self->get('/gms/rest/authentication/logout');
    $self->_error_handler($res)
        unless $res->code == 200;

    return 1;
}

=method get_version

Returns the Silverpeak Orchestrator version.

=cut

sub get_version($self) {
    my $res = $self->get('/gms/rest/gms/versions');
    $self->_error_handler($res)
        unless $res->code == 200;

    return $res->data->{current};
}

=method list_templategroups

Returns an arrayref of template groups.

=cut

sub list_templategroups($self) {
    my $res = $self->get('/gms/rest/template/templateGroups');
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method get_templategroup

Returns a template group by name.

=cut

sub get_templategroup($self, $name) {
    my $res = $self->get('/gms/rest/template/templateGroups/' . $name);
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

1;
