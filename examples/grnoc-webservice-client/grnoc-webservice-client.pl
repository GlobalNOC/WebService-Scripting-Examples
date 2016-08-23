use strict;
use warnings;

use GRNOC::CLI();
use GRNOC::WebService::Client;

use Data::Dumper;

#--- this is the url where the webservice we are hitting lives
my $webservice_url = "https://db2-stage.grnoc.iu.edu/cds2/node.cgi";

#--- use GRNOC::CLI to get the username and password for working with CDS
my $cli = new GRNOC::CLI();

my $username = $cli->get_input('Username');
my $password = $cli->get_password('Password');
print "\n";

#--- instantiate the webservice client object
#--- set the error callback. If there is an error webservice client
#--- will automatically call our error method and we can decide what to do
my $websvc = new GRNOC::WebService::Client(
    url => $webservice_url,
    uid => $username,
    passwd => $password,
    error_callback => \&webservice_error
    );

#--- call the help method to make sure the credentials work.
#--- this will help to prevent being accidentally locked out
#--- if you typo your password
my $result = $websvc->help();

#--- now that we know our credentials work lets call get nodes
$result = $websvc->get_nodes(
    status => 'active',
    limit => 10
    );

#--- loop over the results and print out the node names
foreach my $node (@{$result->{'results'}}){
    print "Found Node '$node->{'name'}'\n";
}

sub webservice_error {
    my $websvc = shift;

    #--- if there is some error we probably dont want to continue on
    #--- just die and print the error message
    die($websvc->get_error());
}
