use Test2::V0;
use Test2::Tools::Compare qw( array hash );
use Net::Silverpeak::Orchestrator;
# use JSON qw();

SKIP: {
    skip_all "environment variables not set"
        unless (exists $ENV{NET_SILVERPEAK_ORCHESTRATOR_HOSTNAME}
            && exists $ENV{NET_SILVERPEAK_ORCHESTRATOR_USERNAME}
            && exists $ENV{NET_SILVERPEAK_ORCHESTRATOR_PASSWORD}
            && exists $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY});
};

my $orchestrator = Net::Silverpeak::Orchestrator->new(
    server      => 'https://' . $ENV{NET_SILVERPEAK_ORCHESTRATOR_HOSTNAME},
    user        => $ENV{NET_SILVERPEAK_ORCHESTRATOR_USERNAME},
    passwd      => $ENV{NET_SILVERPEAK_ORCHESTRATOR_PASSWORD},
    clientattrs => { timeout => 30 },
);

ok($orchestrator->login, 'login to Silverpeak Orchestrator successful');

like($orchestrator->get_version, qr/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/,
    'get_version ok');

is($orchestrator->list_templategroups,
    array {
        etc();
    },
    'list_templategroups ok');

like(
    dies { $orchestrator->get_templategroup('not-existing') },
    qr/Failed to get Templates for group/,
    'get_templategroup for not existing template group throws exception'
);

is(my $templategroup = $orchestrator->get_templategroup('LocalSecurity'),
    hash {
        etc();
    },
    'get_templategroup for existing template group ok');

use Data::Dumper::Concise;
# $Data::Dumper::Maxdepth = 2;
# print Dumper($templategroup->{selectedTemplates});

my ($security_template) = grep { $_->{name} eq 'securityMaps' }
    $templategroup->{selectedTemplates}->@*;

ok($security_template, 'securityMaps template found in template group');

ok(exists $security_template->{value}->{data}->{map1}->{'0_0'}->{prio}
    && ref $security_template->{value}->{data}->{map1}->{'0_0'}->{prio}
        eq 'HASH',
    'securityMaps return data structure as expected');

my $rules = $security_template->{value}->{data}->{map1}->{'0_0'}->{prio};
# print Dumper($rules);
$rules->{1010}->{misc}->{rule} =
    $rules->{1010}->{misc}->{rule} eq 'enable'
    ? 'disable'
    : 'enable';

ok(
    lives {
        $orchestrator->update_templategroup('LocalSecurity', {
            name => 'LocalSecurity',
            templates => [
                {
                    name      => 'securityMaps',
                    valObject => $security_template->{value},
                }
            ]
        });
    }, 'update_templategroup successful') or note($@);

done_testing();
