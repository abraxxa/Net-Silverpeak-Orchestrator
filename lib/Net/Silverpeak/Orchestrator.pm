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

    # OR

    $orchestrator = Net::Silverpeak::Orchestrator->new(
        server      => 'https://orchestrator.example.com',
        api_key     => '$api-key',
        clientattrs => { timeout => 30 },
    );

=head1 DESCRIPTION

This module is a client library for the Silverpeak Orchestrator REST API.
Currently it is developed and tested against version 9.0.2.

=head1 KNOWN SILVERPEAK ORCHESTRATOR BUGS

=over

=item http 500 response on api key authentication

Orchestrator versions before version 9.0.4 respond with a http 500 error on
every request using an api key that has no expriation date set.
The only workaround is to set an expiration date for it.

=back

=for Pod::Coverage has_user has_passwd has_api_key

=cut

has 'user' => (
    isa => Str,
    is  => 'rw',
    predicate => 1,
);
has 'passwd' => (
    isa => Str,
    is  => 'rw',
    predicate => 1,
);
has 'api_key' => (
    isa => Str,
    is  => 'rw',
    predicate => 1,
);

with 'Role::REST::Client';

has '+persistent_headers' => (
    default => sub {
        my $self = shift;
        my %headers;
        $headers{'X-Auth-Token'} = $self->api_key
            if $self->has_api_key;
        return \%headers;
    },
);

around 'do_request' => sub($orig, $self, $method, $uri, $opts) {
    # $uri .= '?apiKey='  . $self->api_key
    #     if $self->has_api_key;
    # warn 'request: ' . Dumper([$method, $uri, $opts]);
    my $response = $orig->($self, $method, $uri, $opts);
    # warn 'response: ' .  Dumper($response);
    return $response;
};

sub _build_user_agent ($self) {
    require HTTP::Thin;

    my %params = $self->clientattrs->%*;
    if ($self->has_user && $self->has_passwd) {
        $params{cookie_jar} = HTTP::CookieJar->new;
    }

    return HTTP::Thin->new(%params);
}

sub _error_handler ($self, $res) {
    my $error_message = $res->data;

    croak('error (' . $res->code . '): ' . $error_message);
}

=method login

Logs into the Silverpeak Orchestrator.
Only required when using username and password, not for api key.

=cut

sub login($self) {
    die "user and password required\n"
        unless $self->has_user && $self->has_passwd;

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
Only possible when using username and password, not for api key.

=cut

sub logout($self) {
    die "user and password required\n"
        unless $self->has_user && $self->has_passwd;

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

=method create_templategroup

Takes a template group name and a hashref with its config.

Returns true on success.

Throws an exception on error.

=cut

sub create_templategroup($self, $name, $data = {}) {
    $data->{name} = $name;
    my $res = $self->post('/gms/rest/template/templateCreate',
        $data);
    $self->_error_handler($res)
        unless $res->code == 204;
    return 1;
}

=method update_templates_of_templategroup

Takes a template group name and an arrayref of template names.

Returns true on success.

Throws an exception on error.

=cut

sub update_templates_of_templategroup($self, $name, $templatenames) {
    croak('templates names must be passed as an arrayref')
        unless ref $templatenames eq 'ARRAY';

    my $res = $self->post('/gms/rest/template/templateSelection/' . $name,
        $templatenames);
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method update_templategroup

Takes a template group name and a hashref of template configs.

Returns true on success.

Throws an exception on error.

=cut

sub update_templategroup($self, $name, $data) {
    my $res = $self->post('/gms/rest/template/templateGroups/' . $name,
        $data);
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method delete_templategroup

Takes a template group name.

Returns true on success.

Throws an exception on error.

=cut

sub delete_templategroup($self, $name) {
    my $res = $self->delete('/gms/rest/template/templateGroups/' . $name);
    $self->_error_handler($res)
        unless $res->code == 204;
    return 1;
}

=method list_appliances

Returns an arrayref of appliances.

=cut

sub list_appliances($self) {
    my $res = $self->get('/gms/rest/appliance');
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method get_appliance

Returns an appliance by id.

=cut

sub get_appliance($self, $id) {
    my $res = $self->get('/gms/rest/appliance/' . $id);
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method list_template_applianceassociations

Returns a hashref of template to appliances associations.

=cut

sub list_template_applianceassociations($self) {
    my $res = $self->get('/gms/rest/template/applianceAssociation');
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method list_applianceids_by_templategroupname

Returns an arrayref of appliance IDs a templategroup is assigned to.

=cut

sub list_applianceids_by_templategroupname($self, $name) {
    my $associations = $self->list_template_applianceassociations;
    my @appliance_ids;
    for my $appliance_id (keys %$associations) {
        push @appliance_ids, $appliance_id
            if any { $_ eq $name } $associations->{$appliance_id}->@*;
    }
    return \@appliance_ids;
}

=method list_addressgroups

Returns an arrayref of address groups.

=cut

sub list_addressgroups($self) {
    my $res = $self->get('/gms/rest/ipObjects/addressGroup');
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method list_addressgroup_names

Returns an arrayref of address group names.

=cut

sub list_addressgroup_names($self) {
    my $res = $self->get('/gms/rest/ipObjects/addressGroupNames');
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method get_addressgroup

Returns a address group by name.

=cut

sub get_addressgroup($self, $name) {
    my $res = $self->get('/gms/rest/ipObjects/addressGroup/' . $name);
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method create_or_update_addressgroup

Takes a address group name and a hashref of address group config.

Returns true on success.

Throws an exception on error.

=cut

sub create_or_update_addressgroup($self, $name, $data) {
    $data->{name} = $name;
    $data->{type} = 'AG';
    my $res = $self->post('/gms/rest/ipObjects/addressGroup', $data);
    $self->_error_handler($res)
        unless $res->code == 204;
    return 1;
}

=method update_addressgroup

Takes a address group name and a hashref of address group config.

Returns true on success.

Throws an exception on error.

=cut

sub update_addressgroup($self, $name, $data) {
    $data->{name} = $name;
    $data->{type} = 'AG';
    my $res = $self->put('/gms/rest/ipObjects/addressGroup', $data);
    $self->_error_handler($res)
        unless $res->code == 204;
    return 1;
}

=method delete_addressgroup

Takes a address group name.

Returns true on success.

Throws an exception on error.

=cut

sub delete_addressgroup($self, $name) {
    my $res = $self->delete('/gms/rest/ipObjects/addressGroup/' . $name);
    $self->_error_handler($res)
        unless $res->code == 204;
    return 1;
}

=method list_servicegroups

Returns an arrayref of service groups.

=cut

sub list_servicegroups($self) {
    my $res = $self->get('/gms/rest/ipObjects/serviceGroup');
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method list_servicegroup_names

Returns an arrayref of service group names.

=cut

sub list_servicegroup_names($self) {
    my $res = $self->get('/gms/rest/ipObjects/serviceGroupNames');
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method get_servicegroup

Returns a service group by name.

=cut

sub get_servicegroup($self, $name) {
    my $res = $self->get('/gms/rest/ipObjects/serviceGroup/' . $name);
    $self->_error_handler($res)
        unless $res->code == 200;
    return $res->data;
}

=method create_or_update_servicegroup

Takes a service group name and a hashref of service group config.

Returns true on success.

Throws an exception on error.

=cut

sub create_or_update_servicegroup($self, $name, $data) {
    $data->{name} = $name;
    $data->{type} = 'SG';
    my $res = $self->post('/gms/rest/ipObjects/serviceGroup', $data);
    $self->_error_handler($res)
        unless $res->code == 204;
    return 1;
}

=method delete_servicegroup

Takes a service group name.

Returns true on success.

Throws an exception on error.

=cut

sub delete_servicegroup($self, $name) {
    my $res = $self->delete('/gms/rest/ipObjects/serviceGroup/' . $name);
    $self->_error_handler($res)
        unless $res->code == 204;
    return 1;
}

1;
