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
        # settings, user data
        copy("templates/user_data.txt", "$work_dir/$node/user_data.txt");
    }
    return $configs;
}

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
	$full_output =~ s/os.networks = \[ "<FILLMEIN>" \]/os.networks = \[ \]/;
	$full_output =~ s/os.networks = \[ "" \]/os.networks = \[ \]/;
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
