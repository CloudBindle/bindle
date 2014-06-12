package cluster::setup;

use IPC::System::Simple;
use common::sense;
use autodie qw(:all);
use Getopt::Long;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';
use Carp::Always;

my $configs;
my $work_dir;
sub setup_os_config_scripts {
    my ($class,$configs, $output_dir, $output_file) = @_;
    $work_dir = $output_dir;
    foreach my $host (sort keys %{$configs}) {
        run("mkdir $output_dir/$host");
        foreach my $script (@{$configs->{$host}{first_pass_scripts}}) {
            autoreplace($script, "$output_file.temp", $configs);
            run("cat $output_file.temp >> $output_dir/$host/$host\_$output_file");
            run("rm $output_file.temp");
        }
    }
}



# this assumes the first pass setup script was created per host by setup_os_config_scripts
# FIXME: should remove the non-generic files processed below if possible, notice how there are project-specific file copies below!
sub prepare_files {
    my ($class, $cluster_configs, $configs, $work_dir, $vb_ram, $vb_cores, @ebs_vols) = @_;
    # Vagrantfile, the core file used by Vagrant that defines each of our nodes
    $configs = setup_vagrantfile("templates/Vagrantfile_start.template", 
                      "templates/Vagrantfile_part.template", 
                      "templates/Vagrantfile_end.template", 
                      $cluster_configs, $configs, "$work_dir", $vb_ram, $vb_cores, @ebs_vols);

    foreach my $node (sort keys %{$cluster_configs}) {
        # cron for SeqWare
        autoreplace("templates/status.cron", "$work_dir/$node/status.cron", $configs);
        # various files used for SeqWare when installed and not built from source
        autoreplace("templates/seqware/seqware-webservice.xml", "$work_dir/$node/seqware-webservice.xml", $configs);
        autoreplace("templates/seqware/seqware-portal.xml", "$work_dir/$node/seqware-portal.xml", $configs);
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
        autoreplace("templates/DCC/settings.yml", "$work_dir/$node/settings.yml",$configs);
        # DCC validator
        copy("templates/dcc_validator/application.conf", "$work_dir/$node/application.conf");
        copy("templates/dcc_validator/init.sh", "$work_dir/$node/init.sh");
    }
    return $configs;
}

# this assumes the first pass script was created per host by setup_os_config_scripts
sub setup_vagrantfile {
    my ($start, $part, $end, $cluster_configs, $configs, $work_dir, $ram, $cores, @ebs_vols) = @_;
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
	print "$node_output\n";
        autoreplace("$start", "$node_output", $configs);
        # FIXME: should change this var to something better
        autoreplace("$part", "$node_output.temp", $configs);
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
    
    return $configs;
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

1;