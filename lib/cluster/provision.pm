package cluster::provision;

use common::sense;
use IPC::System::Simple;
use autodie qw(:all);
use Getopt::Long;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';
use Carp::Always;

my ($configs, $cluster_configs, $work_dir);


sub provision_instances {
    my ($class, $cfgs, $cluster_cfgs,$target_dir, $launch_vcloud,$use_rsync) = @_;
    ($configs, $cluster_configs, $work_dir)=($cfgs, $cluster_cfgs,$target_dir);
    # first, find all the hosts and get their info
    my $hosts = find_cluster_info($cluster_configs,$work_dir);

    # FIXME: this should be better organized and it's own subroutine 
    # general info
    # this is putting in a variable for the /etc/hosts file
    $configs->{HOSTS} =  figure_out_host_str($hosts);
    $configs->{SGE_HOSTS} = figure_out_sge_host_str($hosts);

    # FIXME: notice hard-coded to be "master"
    my $master_pip = $hosts->{master}{pip};
    $configs->{MASTER_PIP} = $hosts->{master}{pip};
    $configs->{EXPORTS} = make_exports_str($hosts);

    # DCC specific stuff
    # for the settings.yml
    $configs->{DCC_PORTAL_SETTINGS_HOST_STR} = make_dcc_portal_host_string($hosts);

    # for the elasticsearch.yml
    $configs->{DCC_ES_HOSTS_STR} = make_dcc_es_host_string($hosts); 
  
    # now process templates to remote destinations
    run_provision_files($cluster_configs, $hosts, $launch_vcloud,$use_rsync);
  
    # this runs over all hosts and calls the provision scripts in the correct order
    run_provision_script_list($cluster_configs, $hosts);

    return;  
}

sub find_cluster_info {
    my ($cluster_config,$work_dir) = @_;

    my (%cluster_info, @node_status, $vagrant_status);
    foreach my $node (sort keys %{$cluster_config}) {
        $vagrant_status = `cd $work_dir/$node && vagrant status`.'\n';
        chomp $vagrant_status;
        find_node_info(\%cluster_info, $vagrant_status);
    }

    return \%cluster_info;
}

# this creates the /etc/hosts additions
sub figure_out_host_str {
    my ($hosts) = @_;
  
    my $hosts_str = "";
    foreach my $host (sort keys %{$hosts}) {
      $hosts_str .= $hosts->{$host}{pip}."  $host\n";
    }

    return $hosts_str;
}

# this creates the sge host list
sub figure_out_sge_host_str {
    my ($hosts) = @_;

    my $hosts_str = "";
    foreach my $host (sort keys %{$hosts}) {
        $hosts_str .= " $host";
    }

    return $hosts_str;
}

# this creates a string to add to /etc/exports
sub make_exports_str {
  my ($hosts) = @_;
  my $result = "";
  my $count = 1;
  foreach my $host (sort keys %{$hosts}) {
    my $pip = $hosts->{$host}{pip};
    $result .= "
/home $pip(rw,fsid=".$count++.",sync,no_root_squash,no_subtree_check)
/mnt/home $pip(rw,fsid=".$count++.",sync,no_root_squash,no_subtree_check)
/mnt/datastore $pip(rw,fsid=".$count++.",sync,no_root_squash,no_subtree_check)
";
  }
  print "EXPORT: $result\n";
  return($result);
}

sub make_dcc_portal_host_string {
    my ($hosts) = @_;
    my $host_str = "";
    foreach my $host (keys %{$hosts}) {
        my $pip = $hosts->{$host}{pip};
        $host_str .= "- host: \"$pip\" port: 9300";
    }

    return $host_str;
}

sub make_dcc_es_host_string {
    my ($hosts) = @_;

    my @host_ids;
    foreach my $host (keys %{$hosts}) {
        push @host_ids, $hosts->{$host}{pip};
    }
 
    return '"'.join('","', @host_ids).'"';
}

# this runs all the "second_pass_scripts" in the json for a given host
sub run_provision_script_list {
  my ($cluster_configs, $hosts) = @_;
  my $cont = 1;
  my $curr_cell = 0;

  while($cont) {
    my @threads = ();
    foreach my $host_name (sort keys %{$hosts}) {
      say "  PROVISIONING HOST $host_name FOR PASS $curr_cell";
      my $scripts = $cluster_configs->{$host_name}{second_pass_scripts};
      my $host = $hosts->{$host_name};
      if ($curr_cell >= scalar(@{$scripts})) { 
          $cont = 0;
      }    
      else {
          my $curr_scripts = $scripts->[$curr_cell];
          push @threads, threads->create(\&provision_script_list_thread, $host_name, $host, $curr_scripts, $curr_cell);
      }
    }
    foreach my $thr (@threads){
      $thr->join();
    }
    $curr_cell++;
  }
}

# processes and copies files to the specific hosts
sub run_provision_files {
    my ($cluster_configs, $hosts, $launch_vcloud, $use_rsync) = @_;

    my @threads;
    foreach my $host_name (sort keys %{$hosts}) {
        my $scripts = $cluster_configs->{$host_name}{provision_files};
        my $host = $hosts->{$host_name};
        say "  PROVISIONING FILES TO HOST $host_name"; 
        if ($use_rsync){
            run("rsync -e \"ssh -i $host->{key}\" -avz $work_dir/$host_name/ $host->{user}".'@'."$host->{ip}:/vagrant/");
        }
        push @threads, threads->create(\&provision_files_thread,
                                         $host_name, $scripts, $host);
        say "  LAUNCHED THREAD PROVISION FILES TO $host_name";
    }

    # Now wait for the threads to finish; this will block if the thread isn't terminated
    foreach my $thread (@threads){
        $thread->join();
    }

}

sub find_node_info {
    my ($cluster_info, $vagrant_status) = @_;

    my $host_id = get_host_id_from_vagrant_status($vagrant_status);

    if ($host_id ne "" && defined($cluster_configs->{$host_id})) {
       $cluster_info->{$host_id} = host_information($work_dir, $host_id);
    }
 
}

sub get_host_id_from_vagrant_status {
    my ($status) = @_;

    if ($status =~ /Current machine states:\s+(\S+)\s+(active|running)/) { # openstack and vcloud ar running, aws is running
        return $1;
    } 
    die 'Was unable to get node infomation';
}

sub host_information {
    my ($sork_dir, $host_id) = @_;
  
    my $host_info = `cd $work_dir/$host_id && vagrant ssh-config $host_id`;
    my @hosts_info = split "\n", $host_info;

    my %host;
    foreach my $hl (@hosts_info) {
        chomp $hl;

        if ($hl =~ /HostName\s+(\S+)/) { 
            $host{ip} = $1;
        }
        elsif ($hl =~ /User\s+(\S+)/) { 
            $host{user} = $1;
        }
        elsif ($hl =~ /IdentityFile\s+(\S+)/) { 
           $host{key} = $1;
        }
        elsif ($hl =~ /Port\s+(\S+)/) {
           $host{port} = $1;
        }
    }

    my $pip = get_pip_id($work_dir, $host_id, \%host);
    $host{pip} = $pip if ($pip); 

    return \%host; 
}

sub get_pip_id {
    my ($work_dir, $host_id, $host) = @_;
 
    my $pip = `cd $work_dir/$host_id && ssh -p $host->{port} -o StrictHostKeyChecking=no -i $host->{key} $host->{user}\@$host->{ip} \"/sbin/ifconfig | grep -A 1 eth0 | grep inet\"`;

    return ($pip =~ /addr:(\S+)/)? $1: 0;
}

sub provision_files_thread {
    my ($host_name, $scripts, $host) = @_;

    say "    STARTING THREAD TO PROVISION FILES TO HOST $host_name";
    # now run each of these scripts on this host
    foreach my $script (keys %{$scripts}) {
        say "  PROCESSING FILE FOR HOST: $host_name FILE: $script DEST: ".$scripts->{$script};
        $script =~ /\/([^\/]+)$/;
        my $script_name = $1;
        system("mkdir -p $work_dir/scripts/");
        my $tmp_script_name = "$work_dir/scripts/tmp_$host_name\_$script_name";

        # set the current host before processing file
        setup_os_config_scripts_list($script, $tmp_script_name);
        run("scp -P ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." $tmp_script_name ".$host->{user}."@".$host->{ip}.":".$scripts->{$script}, $host_name);
        system("rm $tmp_script_name");
    }
    
}

sub provision_script_list_thread {
    my ($host_name, $host, $curr_scripts, $curr_cell) = @_;

    my $local_configs = dclone $configs;
    # now run each of these scripts on this host
    foreach my $script (@{$curr_scripts}) {
        print "  RUNNING PASS FOR HOST: $host_name ROUND: $curr_cell SCRIPT: $script\n";
        $script =~ /\/([^\/]+)$/;
        my $script_name = $1;
        system("mkdir -p $work_dir/scripts/");
        # set the current host before processing file
        $local_configs->{'HOST'} = $host_name;
        setup_os_config_scripts_list($script, "$work_dir/scripts/config_script.$host_name\_$script_name", $local_configs);
        run("ssh -p ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." ".$host->{user}."@".$host->{ip}." sudo mkdir -p /vagrant_scripts", $host_name);
        run("ssh -p ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." ".$host->{user}."@".$host->{ip}." sudo chmod a+rwx /vagrant_scripts", $host_name);
        run("scp -P ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." $work_dir/scripts/config_script.$host_name\_$script_name ".$host->{user}."@".$host->{ip}.":/vagrant_scripts/config_script.$host_name\_$script_name && ssh -p ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." ".$host->{user}."@".$host->{ip}." sudo bash -i /vagrant_scripts/config_script.$host_name\_$script_name", $host_name);
    }
}

# this basically cats files together after doing an autoreplace
sub setup_os_config_scripts_list {
    my ($config_scripts, $output, $configs) = @_;

    my @scripts = split /,/, $config_scripts;

    foreach my $script (@scripts) {
        autoreplace($script, "$output.temp", $configs); 
        run("cat $output.temp >> $output");
        run("rm $output.temp");
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
