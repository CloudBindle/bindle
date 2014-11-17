package cfg;

use common::sense;

use Config::Simple;

use FindBin qw($Bin);

use Carp::Always;
use autodie qw(:all);

sub read_config {
    my ($class, $config_name, $cluster_name) = @_;

    my $config = new Config::Simple();

    unless (-d ($ENV{"HOME"}."/.bindle")) {
        `cp -R $Bin/../templates/config/ $ENV{"HOME"}/.bindle/`;
        die "~/.bindle has been created with sample configuration files. Parameterize the desired configuration file and then re-run script"
    }

    my $config_file = $ENV{"HOME"}."/.bindle/$config_name.cfg";

    die "Please create config file: $config_file" unless (-e $config_file);

    $config->read($config_file) or die $config->error();

    return $config;
}

1;
