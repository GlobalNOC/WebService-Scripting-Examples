use strict;
use warnings;

use GRNOC::Config();

use Data::Dumper;

#--- location on disk of my config file
my $config_file = "conf/config.xml";

#--- instantiate the config file
my $cfg = new GRNOC::Config( config_file => $config_file );

#--- pull the cds credentials out of the config file
my $cds_username = $cfg->get('/config/cds_credentials/@username')->[0];
my $cds_password = $cfg->get('/config/cds_credentials/@password')->[0];

print "Found CDS Credentials. Username '$cds_username', Password '$cds_password'\n";

#--- pull the network_id to run on from the config file
my $network_id = $cfg->get('/config/network/@id')->[0];

print "Found Network ID '$network_id'\n";

#--- pull the node webservice urlfrom the config file
my $node_webservice_url = $cfg->get('/config/node_webservice/@url')->[0];

print "Found Node WebService URL '$node_webservice_url'\n";

#--- pull the node roles to run on from the config file
#--- since webservice client uses array natively it works well to leave this as an array ref
#--- for easy pass off to the client.
my $node_roles = $cfg->get('/config/node_roles/node_role/@value');
print Dumper($node_roles);
