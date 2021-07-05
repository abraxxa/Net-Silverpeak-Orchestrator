use Test2::V0;
use Test2::Tools::Compare qw( array bag hash );
use Net::Silverpeak::Orchestrator;

skip_all "environment variables not set"
    unless (exists $ENV{NET_SILVERPEAK_ORCHESTRATOR_HOSTNAME}
        && exists $ENV{NET_SILVERPEAK_ORCHESTRATOR_USERNAME}
        && exists $ENV{NET_SILVERPEAK_ORCHESTRATOR_PASSWORD}
        && exists $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY});

my $orchestrator = Net::Silverpeak::Orchestrator->new(
    server      => 'https://' . $ENV{NET_SILVERPEAK_ORCHESTRATOR_HOSTNAME},
    user        => $ENV{NET_SILVERPEAK_ORCHESTRATOR_USERNAME},
    passwd      => $ENV{NET_SILVERPEAK_ORCHESTRATOR_PASSWORD},
    clientattrs => { timeout => 30 },
);

ok($orchestrator->login, 'login to Silverpeak Orchestrator successful');

END {
    diag('logging out');
    $orchestrator->logout
        if defined $orchestrator;
}

like($orchestrator->get_version, qr/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/,
    'get_version ok');

is(my $templategroups = $orchestrator->list_templategroups,
    array {
        etc();
    },
    'list_templategroups ok');

isnt($templategroups,
    bag {
        item hash {
            field name => $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY};
            etc();
        };

        etc();
    },
    "template group '" . $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY} .
        "' doesn't exist"
);

like(
    dies { $orchestrator->get_templategroup('not-existing') },
    qr/Failed to get Templates for group/,
    'get_templategroup for not existing template group throws exception'
);

ok($orchestrator->create_templategroup(
    $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY}),
    "template group '" . $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY} .
        "' created");

END {
    diag("deleting template group 'Net-Silverpeak-Orchestrator-Test'");
    $orchestrator->delete_templategroup(
        $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY})
        if defined $orchestrator;
}

ok($orchestrator->update_templates_of_templategroup(
    $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY}, ['securityMaps']),
    "Security Policy added to template group '" .
    $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY} . "'");

is(my $templategroup = $orchestrator->get_templategroup(
    $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY}),
    hash {
        etc();
    },
    'get_templategroup for existing template group ok');

my ($security_template) = grep { $_->{name} eq 'securityMaps' }
    $templategroup->{selectedTemplates}->@*;

ok($security_template, 'securityMaps template found in template group');

ok(exists $security_template->{value}->{data}->{map1}
    && ref $security_template->{value}->{data}->{map1}
        eq 'HASH',
    'securityMaps return data structure as expected');

$security_template->{value}->{data}->{map1}->{'0_0'}->{prio}->{1010} =
    {
        match=> {
            dst_ip => "10.0.0.10/32|10.0.0.11/32",
            dst_port => 53,
            protocol => "udp",
            src_ip => "10.0.0.0/24",
        },
        misc => {
            logging => "disable",
            rule => "enable",
            tag => 'rule_1',
        },
        set => {
            action => "allow",
        },
    };

ok(
    lives {
        $orchestrator->update_templategroup(
        $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY}, {
            name => $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY},
            templates => [
                {
                    name      => 'securityMaps',
                    valObject => $security_template->{value},
                }
            ]
        });
    }, 'update_templategroup successful') or note($@);

is(my $appliances = $orchestrator->list_appliances,
    array {
        etc();
    },
    'list_appliances ok');

ok(
    dies { $orchestrator->get_appliance('not-existing') },
    'get_appliance for not existing appliance throws exception'
);

is($orchestrator->list_template_applianceassociations,
    hash {
        etc();
    },
    'list_template_applianceassociations ok');

SKIP: {
    skip "Orchestrator has no appliances"
        unless $appliances->@*;

    is($orchestrator->get_appliance($appliances->[0]->{id}),
        hash {
            etc();
        },
        'get_appliance for existing appliance ok');

    is($orchestrator->list_applianceids_by_templategroupname(
        $ENV{NET_SILVERPEAK_ORCHESTRATOR_POLICY}),
        array {
            all_items match qr/^[0-9]+\.[A-Z]+$/;

            etc();
        },
        'list_appliances_by_templategroupname ok');
}

is($orchestrator->list_addressgroup_names,
    bag {
        all_items match qr/^[a-zA-Z0-9_\-\.]+$/;

        end();
    },
    'list_addressgroup_names ok');

is($orchestrator->list_addressgroups,
    bag {
        all_items hash {
            field name => match qr/^[a-zA-Z0-9_\-\.]+$/;
            field type => 'AG';
            field rules => bag {
                all_items hash {
                    field includedIPs => array {
                        etc();
                    };
                    field excludedIPs => array {
                        etc();
                    };
                    field includedGroups => array {
                        etc();
                    };
                    field comment => E();

                    end();
                };

                end();
            };

            end();
        };

        end();
    },
    'list_addressgroups ok');

ok($orchestrator->create_or_update_addressgroup('Testgroup1', {
        rules => [
            {
                includedIPs => [qw(
                    10.2.0.0/24
                    10.3.0.1-15
                    10.0.0.2
                    10.0.0.1
                    10.3.0.30-40
                    10.1.0.0/24
                )],
            },
        ],
    }),
    'create_or_update_addressgroup ok');

is($orchestrator->get_addressgroup('Testgroup1'),
    hash {
        field name => 'Testgroup1';
        field type => 'AG';
        field rules => array {
            item hash {
                field includedIPs => array {
                    item '10.2.0.0/24';
                    item '10.3.0.1-15';
                    item '10.0.0.2';
                    item '10.0.0.1';
                    item '10.3.0.30-40';
                    item '10.1.0.0/24';
                    end();
                };
                field excludedIPs => array {
                    end();
                };
                field includedGroups => array {
                    end();
                };
                field comment => U();

                end();
            };

            end();
        };

        end();
    },
    'get_addressgroup ok');

ok($orchestrator->delete_addressgroup('Testgroup1'),
    'delete_addressgroup ok');

done_testing();
