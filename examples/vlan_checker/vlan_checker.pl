use strict;
use warnings;

use GRNOC::CLI;
use GRNOC::Config;
use GRNOC::WebService::Client;

use MIME::Lite;

use Data::Dumper;

#--- where to send email
my $email_to = 'thompsbp@grnoc.iu.edu,daldoyle@grnoc.iu.edu';

#--- get credentials and network to run on from the config.
my $config_file = 'conf/config.xml';

my $cfg = new GRNOC::Config( config_file => $config_file );

my $cds_username = $cfg->get('/config/cds_credentials/@username')->[0];
my $cds_password = $cfg->get('/config/cds_credentials/@password')->[0];

my $network_id = $cfg->get('/config/network/@id')->[0];

#--- Web Service Locations
my $circuit_webservice_url = 'https://db2-stage.grnoc.iu.edu/cds2/circuit.cgi';
my $node_webservice_url = 'https://db2-stage.grnoc.iu.edu/cds2/node.cgi';

#--- Initialize the webservice client object
#--- since we have two urls we need to talk to we initialize without a url.
#--- we will set the url later before we talk to each service.
my $websvc = new GRNOC::WebService::Client(
    uid => $cds_username,
    passwd => $cds_password,
    usePost => 1,
    error_callback => \&webservice_error
    );

$websvc->set_url($circuit_webservice_url);

#--- get the vlan circuit type id
my $result = $websvc->get_circuit_types( name => 'VLAN' )->{'results'}->[0];
my $ckt_type_id = $result->{'circuit_type_id'};

#--- now get all the vlan circuits
my $vlans = $websvc->get_circuits( 
    circuit_type_id => $ckt_type_id,
    network_id => $network_id,
    status => 'active'
    )->{'results'};

#--- to use these circuits to find the endpoints we need to first loop over them and pull out their circuit id's into an array
my $ckt_ids;

foreach my $vlan (@$vlans){
    push(@$ckt_ids,$vlan->{'circuit_id'});
}

#--- now we have all of the circuits we need to get their endpoints
#---
#--- NOTE: Be careful when sending the results of one call (in this instance get_circuits)
#--- to another method. The results can be very large and result in lots of load on CDS.
#--- in this example we don't need to worry about that. But in other scripts you may need to 
#--- WebService Client's pagination features to make the requests.
my $endpoints = $websvc->get_circuit_endpoints(
    circuit_id => $ckt_ids
    )->{'results'};

#--- in this example we only care about endpoints with interfaces set.
#--- we will need a way to get back to the circuit in question if the interface
#--- does not have a bandwidth set.
#--- We can do that with a hash from interface id to list of circuits its and endpoint for.
my $intf_to_ckt_map;
foreach my $endpoint (@$endpoints){
    if($endpoint->{'interface_id'}){
        push(@{$intf_to_ckt_map->{$endpoint->{'interface_id'}}},$endpoint->{'circuit_name'})
    }
}

#--- now we need to switch over to the node web service and get the interfaces so we can
#--- look at whether or not they have a max bandwidth set.
$websvc->set_url($node_webservice_url);

my @interface_ids = keys(%$intf_to_ckt_map);

my $interfaces = $websvc->get_interfaces(
    interface_id => \@interface_ids
    )->{'results'};

#--- the email body we are going to send out.
my $email_str;

foreach my $interface (@$interfaces){
    if(!defined($interface->{'max_bps'})){
        $email_str .= "Interface $interface->{'abbr_name'} on node $interface->{'node_name'} has not max bandwidth set. This effects the following vlans\n";
        
        my $ckts = $intf_to_ckt_map->{$interface->{'interface_id'}};
        foreach my $ckt (@$ckts){
            $email_str .= "$ckt\n";
        }
    }
}

my $email = new MIME::Lite(
    From => 'automated-reports@grnoc.iu.edu',
    To => $email_to,
    Subject => 'Max bandwidth not set on interfaces.',
    Data => $email_str
    );

$email->send();

sub webservice_error {
    my $websvc = shift;

    die($websvc->get_error());
}
