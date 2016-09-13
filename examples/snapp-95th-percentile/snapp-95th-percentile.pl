use strict;
use warnings;

use GRNOC::CLI;
use GRNOC::Config;
use GRNOC::WebService::Client;

use MIME::Lite;

use Data::Dumper;

#--- where to send email
my $email_to = 'daldoyle@grnoc.iu.edu';

my $cli = GRNOC::CLI->new();
my $username = $cli->get_input("Username: ");
my $password = $cli->get_password("Password: ");


#--- Web Service Locations
my $snapp_webservice_url = 'https://tsds.bldc.grnoc.iu.edu/tsds/services/query.cgi';

#--- Initialize the webservice client object
#--- Make sure to set error_callback so that any errors get handled
#--- for us automatically
my $websvc = new GRNOC::WebService::Client(uid     => $username,
					   passwd  => $password,
					   usePost => 1,
					   error_callback => \&webservice_error
    );

$websvc->set_url($snapp_webservice_url);

#--- Build up our query
#--- Our use case here is that we want to find 95th percentile circuit data
#--- for any circuit tagged with both the "backbone" and "SDN" roles that is
#--- a "100GE" circuit in the "Internet2 Network"
#--- We're going to grab the 1 hour averages because it's really efficient to do
#--- so, but it can be tailored to specific needs.
my $query = "get ";
$query   .= "  percentile(aggregate(values.input, 3600, average), 95) as in_95,";
$query   .= "  percentile(aggregate(values.output, 3600, average), 95) as out_95,";
$query   .= "  node,";
$query   .= "  intf,";
$query   .= "  circuit.name";
$query   .= " between(now - 24h, now)";
$query   .= " by intf, node, circuit.name";
$query   .= " from interface";
$query   .= " where network = \"Internet2 Network\""; 
$query   .= "   and circuit.role = \"backbone\" and circuit.role = \"SDN\"";
$query   .= "   and circuit.type = \"100GE\"";
$query   .= " ordered by circuit.name, node, intf";

#--- issue our query to TSDS
my $results = $websvc->query( query => $query )->{'results'};

#--- now that we have all the results broken down by interface,
#--- we can stich some of it together to form a per circuit view
#--- In this case a circuit's data is the same just flip flopped
#--- depending on which side you're viewing
my %seen;

#--- we're really concerned if >= 30Gbps is reached on any of
#--- these circuits, and somewhat concerned if >= 15Gbps
my $critical_threshold = 30 * (1000 * 1000 * 1000); 
my $warn_threshold     = 15 * (1000 * 1000 * 1000);

my @critical;
my @warning;
my @ok;

foreach my $result (@$results){
    my $circuit = $result->{'circuit.name'};
    my $in95    = $result->{'in_95'};
    my $out95   = $result->{'out_95'};

    #--- if we already saw the other side of this circuit,
    #--- we don't care about it for this report since it adds nothing
    next if ($seen{$circuit});
    $seen{$circuit} = 1;

    #--- categorize each result according to whether it surpassed
    #--- our desired thresholds. This will make formatting nice
    #--- and easy below
    if ($in95 >= $critical_threshold || $out95 >= $critical_threshold){
	push(@critical, $result);
    }
    elsif ($in95 >= $warn_threshold || $out95 >= $warn_threshold){
	push(@warning, $result);
    } 
    else {
	push(@ok, $result);
    }
}


#--- Now that we have categorized our results, let's build up a fancy
#--- HTML email report and send that out
my $email_string = "<html><body>";

$email_string .= "<h4>Circuits > " . format_number($critical_threshold) . " 95th percentile:</h4>\n";
$email_string .= format_result_set(\@critical);

$email_string .= "<h4>Circuits > " . format_number($warn_threshold) . " 95th percentile:</h4>\n";
$email_string .= format_result_set(\@warning);

$email_string .= "<h4>Circuits that are ok:</h4>\n";
$email_string .= format_result_set(\@ok);

$email_string .= "</body></html>";

my $email = new MIME::Lite(
    From => 'automated-reports@grnoc.iu.edu',
    Type => 'text/html',
    To => $email_to,
    Subject => '95th percentile 100GE backbone+SDN report',
    Data => $email_string
    );

$email->send();

sub format_result_set {
    my $results = shift;
  
    my $string = "<table>";
    $string  .= "<tr><th>Circuit</th><th>Input 95th</th><th>Output 95th</th></tr>\n";
    
    foreach my $result (@$results){
	$string   .= "<tr>";
	$string   .= "<td>$result->{'circuit.name'}</td>";
	$string   .= "<td>" . format_number($result->{'in_95'}) . "</td>";
	$string   .= "<td>" . format_number($result->{'out_95'}) . "</td>";
	$string   .= "</tr>\n";
    }

    $string .= "</table>\n";
}

#--- little function to convert from bps to Gbps 
#--- and format pretty-ily for the report
sub format_number {
    my $number = shift;

    my $formatted = sprintf('%.2f', $number / (1000 * 1000 * 1000));

    return $formatted . " Gbps";
}

sub webservice_error {
    my $websvc = shift;

    die($websvc->get_error());
}
