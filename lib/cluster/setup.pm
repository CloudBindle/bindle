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
       'BOX_URL' => $config->param('platform.box_url'),
       'BOX'     => $config->param('platform.box'),
       'custom_hostname' => $node,
    );

    if ($platform eq 'virtualbox') {
        if ($config->param('platform.vb_ram') ) {
           $vagrantfile_map{VB_RAM} = $config->param('plaform.vb_ram');
        }
        else {
            die 'Specify the parameter vb_ram in the platform block of the config file';
        }
        if ($config->param('platform.hostname') ) {
            $vagrantfile_map{VB_CORES} = $config->param('plaform.vb_cores');
        }
        else {
            die 'Specify the parameter vb_cores in the platform block of the config file';
        }

        my @ebs_vols = $config->param('plaform_vols');
        if (scalar @ebs_vols > 0) {
                $vagrantfile_map{AWS_EBS_VOLS} .= "aws.block_device_mapping = [";
                # starts at "f=102"
                my $count = 102;
                foreach my $size (@ebs_vols){
                    my $current_name = chr $count;
    	            $vagrantfile_map{AWS_EBS_VOLS} .= "{'DeviceName' => \"/dev/sd$current_name\", 'VirtualName' => \"block_storage\", 'Ebs.VolumeSize' => $size, 'Ebs.DeleteOnTermination' => true},";
    	        $count++;
    	    }
            chop $vagrantfile_map{AWS_EBS_VOLS};
    	    $vagrantfile_map{AWS_EBS_VOLS} .= "]";
        }
        else {
            die 'Specify the parameter ebs_vols in the platform block of the config file';
        }
    }
    elsif ($platform eq 'vcloud') {
        if (my $hostname = $config->param('platform.hostname') ) {
            $vagrantfile_map{VCLOUD_HOSTNAME} = $hostname;
        }
        else {
            die 'Specify the parameter hostname in the platform block of the config file';
        }
        if (my $username = $config->param('platform.username') ) {
            $vagrantfile_map{VCLOUD_USERNAME} = $username;
        }
        else { 
            die 'Specify the parameter username in the platform block of the config file';
        }
        if (my $password = $config->param('platform.password')) {
           $vagrantfile_map{VCLOUD_PASSWORD} = $password;
        }
        else {
            die 'Specify the parameter password in the platform block of the config file';
        }
        if (my $org_name = $config->param('platform.org_name') ) {
           $vagrantfile_map{VCLOUD_ORG_NAME} = $org_name;
        }
        else {
            die 'Specify the parameter org_name in the platform block of the config file';
        }
        if (my $vdc_name = $config->param('platform.vdc_name') ) {
           $vagrantfile_map{VCLOUD_VDC_NAME} = $vdc_name;
        }
        else {
            die 'Specify the parameter vdc_name in the platform block of the config file';
        }
       if (my $catalog_name = $config->param('platform.catalog_name') ) {
           $vagrantfile_map{VCLOUD_CATALOG_NAME} = $catalog_name;
        }
        else {
            die 'Specify the parameter catalog in the platform block of the config file';
        }
        if (my $vdc_network_name = $config->param('platform.vdc_network_name') ) {
        $vagrantfile_map{VCLOUD_VDC_NETWORK_NAME} = $vdc_network_name;
        }
        else {
            die 'Specify the parameter vdc_network_name in the platform block of the config file';
        }
        if (my $ssh_key_name = $config->param('platform.ssh_key_name') ) {
            $vagrantfile_map{VCLOUD_SSH_PEM_FILE} = "~/.ssh/$ssh_key_name.pem";
        }
        else {
            die 'Specify the parameter ssh_key_name in the platform block of the config file';
        }

        
    }
    elsif( $platform eq 'aws') {
        if (my $key = $config->param('platform.key') ) {
            $vagrantfile_map{AWS_KEY} = $key;
        }
        else {
            die 'Specify the parameter key (AWS_KEY) in the platform block of the config file';
        }
    }

=head
        $configs->{OS_FLOATING_IP} = $cluster_configs->{$node}{floatip};

=cut
 
    return \%vagrantfile_map;
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
