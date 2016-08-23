use strict;
use warnings;

use GRNOC::CLI;

my $cli = new GRNOC::CLI();

my $username = $cli->get_input("Username");
my $password = $cli->get_password("Password");
print "\n";

print "Received username: '$username' and password '$password'\n";
