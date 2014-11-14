#!/usr/bin/env perl

use common::sense;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Config::Simple;
use IPC::System::Simple;
use autodie qw(:all);
use Getopt::Euclid;

use JSON;

use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';
use Carp::Always;

use cfg;
use provision;
use setup;

# VARS

# Notes:
# OS_AUTH_URL=https://api.opensciencedatacloud.org:5000/sullivan/v2.0/
# EC2_URL=https://api.opensciencedatacloud.org:8773/sullivan/services/Cloud

# TODO:
# * parallel node launching, each with their own target dir (vs. having Vagrant launch multiple nodes). This will be faster but more work on my part.
# * the box URLs are hardcoded, add them to the config JSON file instead
# * there's a lot of hacking on the $configs hash in the code, for example defining the master private IP. This is dangerous.
# * It would be great to use Template::Toolkit for the Vagrantfile and other files we need to do token replacement in
# * add very clear delimiters to each provision step saying what machine is being launched, add DONE to the end

# skips all unit and integration tests
my $config_name = $ARGV{'--config'};
my $custom_block = $ARGV{'--custom-params'};

my $config = cfg->read_config($config_name, $custom_block);

my $parameters = $config->param(-block=>'defaults');

if ($custom_block) {
   my $custom_params = $config->param(-block=>$custom_block);
   die 'Cluster specified does not exist in config file located in ~/.bindle'
                                               unless (keys %{$custom_params} );
   my %parameters_dref = %{$parameters};
   @parameters_dref{keys %{$custom_params}} = values %{$custom_params};
    $parameters = \%parameters_dref;
}


my $work_dir = $parameters->{target_directory};
die "target-directory was not specified in the configuration file" unless($work_dir);

my $number_of_nodes = $parameters->{number_of_nodes};
die "Please specify the number of nodes in the configuration file" unless ($number_of_nodes);

my $types =  $parameters->{types};

# hash of arrays, mapping from types to arrays of hostnames  
my %nodeHash = ();
# for existing code, a list of hostnames
my @nodes;

if (defined $types){
    # splitting with '::', using commas seems to fail horribly and I can't locate the docs for cfg to figure out why
    my @typeArray = split '::', $types;
    if (scalar @typeArray != $number_of_nodes){
        die "Number of node types does not match number of nodes";
    }
    foreach my $type (@typeArray){
        if (exists $nodeHash{$type}){
	    my @existingArray = @{$nodeHash{$type}};
	    my $count = scalar @existingArray + 1;
	    push @existingArray, "$type$count";
            $nodeHash{$type} = \@existingArray;
        } else {
	    my @arrayStart = ($type);
	    $nodeHash{$type} = \@arrayStart;
	}
    }
}
else{
    print "No node types defined, assuming one master and n-1 worker nodes\n";
    my @masterNodes = ("master");
    $nodeHash{ 'master' } = \@masterNodes;
    my @workerNodes;
    if ($number_of_nodes > 1){
        foreach my $i (1..($number_of_nodes-1)) {
            push @workerNodes, "worker$i";
        }
        $nodeHash{ "worker" } = \@workerNodes;
    }
}

# populate existing array for backwards compatibility
for my $type ( keys %nodeHash ) {
    my @names = @{$nodeHash{$type}};
    for my $name (@names){
        push @nodes, $name;
    }
}

unless (-d $work_dir) {
    my $platform = $config->param('defaults.platform');
    my $launch_command = "vagrant up";
    $launch_command .= " --provider ".$parameters->{platform} unless($config_name eq 'virtualbox');

    run("mkdir -p $work_dir");
    
    # create our working directories for Vagrantfile(s)
    foreach my $node (@nodes) {
        run("mkdir $work_dir/$node");
    }
  
    setup->prepare_files( \@nodes, $parameters);
  
    launch_instances($work_dir, $launch_command, \@nodes);
}

provision->provision_instances(\@nodes, $work_dir, $config, %nodeHash);

say "FINISHED";

sub launch_instances {
    my ($work_dir, $launch_command, $nodes) = @_;

    my @threads;
    foreach my $node (@{$nodes}) {  
        say "LAUNCHING NODE: $node";
        my $thr = threads->create(\&launch_instance, ($work_dir, $node, $launch_command));
        push (@threads, $thr);
        # attempt to prevent RequestLimitExceeded on Amazon by sleeping between thread launch 
        # http://docs.aws.amazon.com/AWSEC2/latest/APIReference/api-error-codes.html
        sleep 90;
    }
    say '  ALL NODES ARE BEING LAUNCHED';
    foreach my $thr (@threads){
        $thr->join();
    }
    say '  ALL LAUNCH THREADS COMPLETED';
}

sub launch_instance {
    my ($work_dir, $node, $launch_command) = @_;
    
    run("cd $work_dir/$node && $launch_command", $node);
}

sub run {
    my ($cmd, $hostname) = @_;

    my $outputfile = "";
    # by default pipe to /dev/null if no hostname is specified, this 
    # will prevent a default.log file from being a mixture of different thread's output
    my $final_cmd = "bash -c '$cmd' > /dev/null 2> /dev/null";
    # only output to host-specific log if defined
    if (defined($hostname)){
        $outputfile = "$work_dir/$hostname.log";
        $final_cmd = "bash -c '$cmd' >> $outputfile 2>&1";
    } 

    say "RUNNING: $final_cmd";
    if ($final_cmd =~ /vagrant up/) {
        no autodie qw(system);
        system($final_cmd);
        say 'launched machine!';
    }
    else {
        system($final_cmd);
    }
}
