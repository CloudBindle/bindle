#!/usr/bin/env perl

use common::sense;

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Data::Dumper;
use Config::Simple;
use IPC::System::Simple;
use autodie qw(:all);
use Getopt::Long;
use JSON;
#use Template;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';
use Carp::Always;
use cluster::config;
use cluster::provision
# VARS

# Notes:
# OS_AUTH_URL=https://api.opensciencedatacloud.org:5000/sullivan/v2.0/
# EC2_URL=https://api.opensciencedatacloud.org:8773/sullivan/services/Cloud

# TODO:
# * parallel node launching, each with their own target dir (vs. having Vagrant launch multiple nodes). This will be faster but more work on my part.
# * the box URLs are hardcoded, add them to the config JSON file instead
# * there's a lot of hard-coded (but relative) file paths in this code which could cause problems if we move around or rename template files
# * this is closely tied to SeqWare so we waste some time downloading and building that tool for other projects that use this tool but don't depend on SeqWare
# * related to the above, there are sections of the code below that are SeqWare-specific, Hadoop-specific, and DCC-specific. Consider breaking these out into their own scripts and defining these in the JSON instead. So this core script is a very lean cluster builder script and anything tool-specific (except maybe hadoop or SGE) are out on their own. For now I'm leaving SeqWare items in the below since it causes no harm to other projects using this cluster launcher.
# * or an alternative is just to sync all the config files instead
# * there's a lot of hacking on the $configs hash in the code, for example defining the master private IP. This is dangerous.
# * It would be great to use Template::Toolkit for the Vagrantfile and other files we need to do token replacement in
# * add very clear delimiters to each provision step saying what machine is being launched, add DONE to the end
# * a better way to handle output from multiple VMs run simultaneously... probably just a nice output for each launched instance with the stderr/stdout going to distinct files in the target dir

# skips all unit and integration tests
my $aws_key = '';
my $aws_secret_key = '';
my ($launch_aws, $launch_vb, $launch_os, $launch_vcloud, $skip_launch) = (0,0,0,0,0);
my $launch_cmd = "vagrant up";
my $work_dir = "target";
my ($vb_ram, $vb_cores) = (12000, 2);
my @ebs_vols = ();
my $default_configs;
my $launch_command = 'vagrant up';
my $cluster_name = 'cluster1';
# check for help
my $help = (scalar @ARGV == 0)? 1 : 0;

GetOptions (
    "use-aws"        => \$launch_aws,
    "use-virtualbox" => \$launch_vb,
    "use-openstack"  => \$launch_os,
    "use-vcloud"     => \$launch_vcloud,
    "launch-cluster=s"  => \$cluster_name,
    "skip-launch"    => \$skip_launch,
    "vb-ram=i"       => \$vb_ram,
    "vb-cores=i"     => \$vb_cores,
    "aws-ebs=s{1,}"  => \@ebs_vols,
    "help"           => \$help,
);

# MAIN
if($help) {
  die "USAGE: $0 --use-aws|--use-virtualbox|--use-openstack|--use-vcloud [--working-dir <working dir path, default is 'target'>] [--config-file <config json file, default is 'vagrant_cluster_launch.json'>] [--vb-ram <the RAM (in MB) to use with VirtualBox only, HelloWorld expects at least 9G, default is 12G>] [--vb-cores <the number of cores to use with Virtual box only, default is 2>] [--aws-ebs <EBS vol size in MB, space delimited>] [--skip-launch] [--help]\n";
}

$launch_command .= cluster::config->set_launch_command($launch_aws, $launch_os, $launch_vcloud);

# config object used for find and replace
my $configs = {};
my $cluster_configs = {};

#reconfigures the worker arrays to the format the original script expects
#also reads in all the default configurations for the appropriate platfrom 
#from the .cfg file in the config folder
($configs, $cluster_configs, $work_dir) = cluster::config->read_default_configs($cluster_name, $launch_vcloud, $launch_aws, $launch_os, $launch_vb);


# dealing with defaults from the config including various SeqWare-specific items
my $default_seqware_build_cmd = 'mvn clean install -DskipTests';
$configs->{'SEQWARE_BUILD_CMD'} //= $default_seqware_build_cmd; 
$configs->{'MAVEN_MIRROR'} //= ""; 

# process server scripts into single bash script
setup_os_config_scripts($cluster_configs, $work_dir, "os_server_setup.sh");

prepare_files($cluster_configs, $configs, $work_dir);

#launch_and_provision_vms($cluster_configs) unless ($skip_launch);

launch_instances($cluster_configs) unless ($skip_launch);
sleep 100;
# FIXME: method needs to be broken into individual steps
# FIXME: this is hacking on the configs object which is not good
# this finds all the host IP addresses and then runs the second provisioning on them
cluster::provision->provision_instances($configs, $cluster_configs, $work_dir) unless ($skip_launch);
say "FINISHED";




# this basically cats files together after doing an autoreplace
# that fills in variables from the config part of the JSON
sub setup_os_config_scripts {
    my ($configs, $output_dir, $output_file) = @_;
    foreach my $host (sort keys %{$configs}) {
        run("mkdir $output_dir/$host");
        foreach my $script (@{$configs->{$host}{first_pass_scripts}}) {
            autoreplace($script, "$output_file.temp");
            run("cat $output_file.temp >> $output_dir/$host/$host\_$output_file");
            run("rm $output_file.temp");
        }
    }
}


sub read_config() {
    my ($file, $config) = @_;
  
    open my $in, '<', $file;
  
    while (<$in>) {
        chomp;
        next if (/^#/);
        if (/^\s*(\S+)\s*=\s*(.*)$/) {
            $config->{$1} = $2;
            #print "$1 \t $2\n";
        }
    }
  
    close $in;
}


sub launch_instances {
    my @threads;
    foreach my $node (sort keys %{$cluster_configs}) {  
        say "  STARTING THREAD TO LAUNCH INSTANCE FOR NODE $node";
        my $thr = threads->create(\&launch_instance, $node);
        push (@threads, $thr);
        # attempt to prevent RequestLimitExceeded on Amazon by sleeping between thread launch 
        # http://docs.aws.amazon.com/AWSEC2/latest/APIReference/api-error-codes.html
        sleep 30;
    }
    print "  ALL LAUNCH THREADS STARTED\n";
    # Now wait for the threads to finish; this will block if the thread isn't terminated
    foreach my $thr (@threads){
        $thr->join();
    }
    print " ALL LAUNCH THREADS COMPLETED\n";
}

sub launch_instance {
    my $node = $_[0];
    
    run("cd $work_dir/$node && $launch_command", $node);
}

# this assumes the first pass setup script was created per host by setup_os_config_scripts
# FIXME: should remove the non-generic files processed below if possible, notice how there are project-specific file copies below!
sub prepare_files {
    my ($cluster_configs, $configs, $work_dir) = @_;

    # Vagrantfile, the core file used by Vagrant that defines each of our nodes
    setup_vagrantfile("templates/Vagrantfile_start.template", 
                      "templates/Vagrantfile_part.template", 
                      "templates/Vagrantfile_end.template", 
                      $cluster_configs, $configs, "$work_dir", $vb_ram, $vb_cores);

    foreach my $node (sort keys %{$cluster_configs}) {
        # cron for SeqWare
        autoreplace("templates/status.cron", "$work_dir/$node/status.cron");
        # various files used for SeqWare when installed and not built from source
        autoreplace("templates/seqware/seqware-webservice.xml", "$work_dir/$node/seqware-webservice.xml");
        autoreplace("templates/seqware/seqware-portal.xml", "$work_dir/$node/seqware-portal.xml");
        # settings, user data
        copy("templates/settings", "$work_dir/$node/settings");
        copy("templates/user_data.txt", "$work_dir/$node/user_data.txt");
        # script for setting up hadoop hdfs
        copy("templates/setup_hdfs_volumes.pl", "$work_dir/$node/setup_hdfs_volumes.pl");
        copy("templates/setup_volumes.pl", "$work_dir/$node/setup_volumes.pl");
        copy("templates/setup_gluster_peers.pl", "$work_dir/$node/setup_gluster_peers.pl");
        copy("templates/setup_gluster_service.pl", "$work_dir/$node/setup_gluster_service.pl");
        copy("templates/setup_gluster_volumes.pl", "$work_dir/$node/setup_gluster_volumes.pl");
        # these are used for when the box is rebooted, it setups the /etc/hosts file for example
        replace("templates/hadoop-init-master", "$work_dir/$node/hadoop-init-master", '%{HOST}', $node);
        replace("templates/hadoop-init-worker", "$work_dir/$node/hadoop-init-worker", '%{HOST}', $node);
        # this is used for the master SGE node to recover when the system is rebooted
        # NOTE: it's not easy to get this same thing to work with reboot for whole clusters
        replace("templates/sge-init-master", "$work_dir/$node/sge-init-master", '%{HOST}', $node);
        # hadoop settings files
        # FIXME: right now these config files have "master" hardcoded as the master node
        # FIXME: break out into config driven provisioner
        copy("templates/conf.worker.tar.gz", "$work_dir/$node/conf.worker.tar.gz");
        copy("templates/conf.master.tar.gz", "$work_dir/$node/conf.master.tar.gz");
        # DCC
        # FIXME: break out into config driven provisioner
        autoreplace("templates/DCC/settings.yml", "$work_dir/$node/settings.yml");
        # DCC validator
        copy("templates/dcc_validator/application.conf", "$work_dir/$node/application.conf");
        copy("templates/dcc_validator/init.sh", "$work_dir/$node/init.sh");
    }
}

# this assumes the first pass script was created per host by setup_os_config_scripts
sub setup_vagrantfile {
    my ($start, $part, $end, $cluster_configs, $configs, $work_dir, $ram, $cores) = @_;

    foreach my $node (sort keys %{$cluster_configs}) {
        $configs->{custom_hostname} = $node;
        $configs->{VB_CORES} = $cores;
        $configs->{VB_RAM} = $ram;
        $configs->{OS_FLOATING_IP} = $cluster_configs->{$node}{floatip};
        if (not exists $configs->{AWS_REGION}){
    	    $configs->{AWS_REGION} = "us-east-1";
        }
        if (not exists $configs->{AWS_ZONE} or $configs->{AWS_ZONE} eq "nil" ){
    	    $configs->{AWS_ZONE} = "nil";
        }
        elsif ($configs->{AWS_ZONE} !~ /^"\S+"$/) { 
            $configs->{AWS_ZONE} = "\"$configs->{AWS_ZONE}\"";
        }

        $configs->{AWS_EBS_VOLS} = "";
        if (scalar @ebs_vols > 0){
            $configs->{AWS_EBS_VOLS} .= "aws.block_device_mapping = [";
            # starts at "f=102"
            my $count = 102;
            foreach my $size (@ebs_vols){
                my $current_name = chr $count;
    	        $configs->{AWS_EBS_VOLS} .= "{'DeviceName' => \"/dev/sd$current_name\", 'VirtualName' => \"block_storage\", 'Ebs.VolumeSize' => $size, 'Ebs.DeleteOnTermination' => true},";
    	        $count++;
    	    }
            chop $configs->{AWS_EBS_VOLS};
    	    $configs->{AWS_EBS_VOLS} .= "]";
        }
        my $node_output = "$work_dir/$node/Vagrantfile";
        autoreplace("$start", "$node_output");
        # FIXME: should change this var to something better
        autoreplace("$part", "$node_output.temp");
        run("cat $node_output.temp >> $node_output");
        run("rm $node_output.temp");
        run("cat $end >> $node_output");
        # hack to deal with empty network/floatIP
        my $full_output = `cat $node_output`;
        # HACK: this is a hack because we don't properly templatize the Vagrantfile... I'm doing this to eliminate empty os.network and os.floating_ip which cause problems on various OpenStack clouds
        $full_output =~ s/os.network = "<FILLMEIN>"//;
        $full_output =~ s/os.network = ""//;
        $full_output =~ s/os.floating_ip = "<FILLMEIN>"//;
        $full_output =~ s/os.floating_ip = ""//;
    
        open my $vout, '>', $node_output;
        print $vout $full_output;
        close $vout;
    }
}


sub autoreplace {
    my ($src, $dest, $local_configs) = @_;

    $local_configs //= $configs;

    say "AUTOREPLACE: $src $dest";

    open my $in, '<', $src;
    open my $out, '>', $dest;

    while(<$in>) {
        foreach my $key (sort keys %{$local_configs}) {
            my $value = $local_configs->{$key};
            $_ =~ s/%{$key}/$value/g;
        }
        print $out $_;
    }

    close $in, $out;
}

sub replace {
    my ($src, $dest, $from, $to) = @_;
  
    say "REPLACE: $src, $dest, $from, $to";

    open my $in, '<', $src;
    open my $out, '>', $dest;
    while(<$in>) {
        $_ =~ s/$from/$to/g;
        print $out $_;
    }
    close $in, $out;
}

sub copy {
    my ($src, $dest) = @_;

    say "COPYING: $src, $dest";

    open my $in, '<', $src;
    open my $out, '>', $dest;
    while(<$in>) {
        print $out $_;
    }
    close $in, $out;
}

sub rec_copy {
    my ($src, $dest) = @_;

    say "COPYING REC: $src, $dest";

    run("cp -r $src $dest");
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