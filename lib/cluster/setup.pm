package cluster::setup;

use IPC::System::Simple;
use common::sense;
use autodie qw(:all);
use Data::Dumper;
use Getopt::Long;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';
use Carp::Always;
use Config::Simple;
my $configs;
my $work_dir;

sub prepare_files {
    my ($class, $platform, $nodes, $config, $work_dir) = @_;

    add_vagrantfiles($config, $platform, $work_dir, $nodes);
    add_user_data_files($nodes, $work_dir);

    return;
}

sub add_user_data_files {
    my ($nodes, $work_dir) = @_;

    foreach my $node (@{$nodes}) {
        copy("templates/user_data.txt", "$work_dir/$node/user_data.txt");
    }
}

sub add_vagrantfiles {
   my ($config, $platform, $work_dir, $nodes) = @_;

   foreach my $node (@{$nodes}) {
        add_vagrantfile($config, $platform, $work_dir, $node);
   }
}

sub add_vagrantfile {
    my ($config, $platform, $work_dir, $node) = @_;

    my $vagrantfile_template_map = vagrantfile_template_map($platform, $node, $config);



    my $vagrantfile = "$work_dir/$node/Vagrantfile";
    say $vagrantfile;
    autoreplace('templates/Vagrantfile.template', $vagrantfile, $vagrantfile_template_map);
    # hack to deal with empty network/floatIP
    my $full_output = `cat $vagrantfile`;
    $full_output =~ s/os.network = "<FILLMEIN>"//;
    $full_output =~ s/os.network = ""//;
	$full_output =~ s/os.networks = \[ "<FILLMEIN>" \]/os.networks = \[ \]/;
	$full_output =~ s/os.networks = \[ "" \]/os.networks = \[ \]/;
    $full_output =~ s/os.floating_ip = "<FILLMEIN>"//;
    $full_output =~ s/os.floating_ip = ""//;

    open my $vout, '>', $vagrantfile;
    print $vout $full_output;
    close $vout;

    return $configs;
}

sub vagrantfile_template_map {
    my ($platform, $node, $config) = @_;

    my %vagrantfile_map = (
       'custom_hostname' => $node,
    );

    my $vagrantfile_map = $config->param(-block=>'platform');
    $vagrantfile_map->{custom_hostname} = $node;

    if ($platform eq 'virtualbox') {
       my @ebs_vols = $config->param('platform.ebs_vols');
        if (scalar @ebs_vols > 0) {
                $vagrantfile_map->{aws_ebs_vols} .= "aws.block_device_mapping = [";
                # starts at "f=102"
                my $count = 102;
                foreach my $size (@ebs_vols){
                    my $current_name = chr $count;
    	            $vagrantfile_map->{aws_ebs_vols} .= "{'DeviceName' => \"/dev/sd$current_name\", 'VirtualName' => \"block_storage\", 'Ebs.VolumeSize' => $size, 'Ebs.DeleteOnTermination' => true},";
    	        $count++;
    	    }
            chop $vagrantfile_map->{aws_ebs_vols};
    	    $vagrantfile_map->{aws_ebs_vols} .= "]";
        }
        else {
            die 'Specify the parameter ebs_vols in the platform block of the config file';
        }
    }

    return $vagrantfile_map;
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
