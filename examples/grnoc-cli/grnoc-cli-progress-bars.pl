use strict;
use warnings;

use GRNOC::CLI;

use Time::HiRes;

my $cli = new GRNOC::CLI();

#--- make a progress bar and count to 1000 sleeping for 1/10th of a second every iteration
$cli->start_progress(
    1000,
    name => 'Making Progress'
    );

for(my $i = 1; $i <= 1000; $i++){
    #--- tell the progress bar what number we are on.
    $cli->update_progress($i);

    #--- print a status message every 100 iterations.
    if($i % 100 == 0){
        $cli->progress_message("Done with $i");
    }

    #--- sleep for 1/10th second
    #--- this sleep is only here to slow the example down to demonstrate the progress bar
    #--- in a real script you probably wont be sleeping
    Time::HiRes::usleep(100000);
}
