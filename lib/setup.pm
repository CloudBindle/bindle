package setup;

use common::sense;

use autodie qw(:all);
use Carp::Always;

use IPC::System::Simple;
use Getopt::Long;

use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';

use Config::Simple;

sub prepare_files {
    my ($class, $nodes, $parameters) = @_;

    add_vagrantfiles($parameters, $nodes);
    add_user_data_files($nodes, $parameters->{target_directory});
}

sub add_user_data_files {
    my ($nodes, $target_directory) = @_;

    foreach my $node (@{$nodes}) {
        copy("templates/user_data.txt", "$target_directory/$node/user_data.txt");
    }
}

sub add_vagrantfiles {
   my ($parameters, $nodes) = @_;

   foreach my $node (@{$nodes}) {
        add_vagrantfile($parameters, $node);
   }
}

sub add_vagrantfile {
    my ($parameters, $node) = @_;

use Data::Dumper;
    $parameters = vagrantfile_template_map($node, $parameters);
    print Dumper $parameters;
    my $vagrantfile = $parameters->{target_directory}."/$node/Vagrantfile";
    say $vagrantfile;
    autoreplace('templates/Vagrantfile.template', $vagrantfile, $parameters);
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
}

sub vagrantfile_template_map {
    my ($node, $parameters) = @_;

    $parameters->{custom_hostname} = $node;

    if ($parameters->{platform} eq 'virtualbox') {
       my @ebs_vols = $parameters->{ebs_vols};
        if (scalar @ebs_vols > 0) {
                $parameters->{aws_ebs_vols} .= "aws.block_device_mapping = [";
                # starts at "f=102"
                my $count = 102;
                foreach my $size (@ebs_vols){
                    my $current_name = chr $count;
    	            $parameters->{aws_ebs_vols} .= "{'DeviceName' => \"/dev/sd$current_name\", 'VirtualName' => \"block_storage\", 'Ebs.VolumeSize' => $size, 'Ebs.DeleteOnTermination' => true},";
    	        $count++;
    	    }
            chop $parameters->{aws_ebs_vols};
    	    $parameters->{aws_ebs_vols} .= "]";
        }
        else {
            die 'Specify the parameter ebs_vols in the config file';
        }
    }

    return $parameters;
}

sub autoreplace {
    my ($src, $dest, $local_configs) = @_;

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

1;
