package cluster::provision;

use common::sense;
use IPC::System::Simple;
use autodie qw(:all);
use Getopt::Long;
use Data::Dumper;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';
use Carp::Always;

my ($configs, $cluster_configs, $work_dir);


sub provision_instances {
    my ($class, $nodes, $work_dir, $config) = @_;

    my $hosts = find_cluster_info($nodes, $work_dir);

    return run_ansible_playbook($work_dir, $hosts, $config);
}

sub find_cluster_info {
    my ($nodes, $work_dir) = @_;

    my (%cluster_info, @node_status, $vagrant_status);
    foreach my $node (@{$nodes}) {
        $vagrant_status = `cd $work_dir/$node && vagrant status`.'\n';
        chomp $vagrant_status;
        find_node_info(\%cluster_info, $vagrant_status, $work_dir);
    }

    return \%cluster_info;
}

sub find_node_info {
    my ($cluster_info, $vagrant_status, $work_dir) = @_;

    my $host_id = get_host_id_from_vagrant_status($vagrant_status);
    $cluster_info->{$host_id} = host_information($work_dir, $host_id);
 
}

sub get_host_id_from_vagrant_status {
    my ($status) = @_;

    if ($status =~ /Current machine states:\s+(\S+)\s+(active|running)/) { # openstack and vcloud ar running, aws is running
        return $1;
    } 
    die 'Was unable to get node infomation';
}

sub host_information {
    my ($work_dir, $host_id) = @_;
  
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

# this generates an ansible inventory and runs ansible
sub run_ansible_playbook {
    my ($work_dir, $hosts, $config) = @_;

    # this could use a specific set module
    my %type_set = ();
    foreach my $host (sort keys %{$hosts}) {
        my $type = ($host)? 'master' : 'worker';
        $type_set{$type} = 1;
    }
 
    open (INVENTORY, '>', "$work_dir/inventory") or die "Could not open inventory file for writing";

    foreach my $type (keys %type_set){
        say INVENTORY "[$type]";
        foreach my $host_name (sort keys %{$hosts}) {
            my $host = $hosts->{$host_name};
            next if (($type eq 'master' and $host_name ne 'master') 
                     or ($type ne 'master' and $host_name eq 'master'));
            say INVENTORY "$host_name\tansible_ssh_host=$host->{ip}\tansible_ssh_user=$host->{user}\tansible_ssh_private_key_file=$host->{key}";
        } 
    }
    say INVENTORY "[all_groups:children]";
    foreach my $type (keys %type_set) {
       say INVENTORY "$type";
    }
    close (INVENTORY); 
   
    my $playbook =  $config->param('platform.ansible_playbook');

    # I'm sure this "cluster" parameter is not how one should do it in Perl, but this seems to work with the call from the launcher which inserts the package
    # as the first parameter
    return run_ansible_command("cluster", $work_dir, $config) if ($playbook);
}

sub run_ansible_command{
    my ($package, $work_dir, $config) = @_;

    my $time = `date +%s.%N`;
    chomp $time;

    my $platform = $config->param(-block=>'platform');

    # create JSON file to pass all defined variables
    # note that ansible variables are lower case by convention while for backwards compatibility, our variables are upper case
    # thus lc while exporting
    open ANSIBLE_VARIABLES, '>', "$work_dir/variables.$time.json";
    my $json = JSON->new->allow_nonref;
    print ANSIBLE_VARIABLES $json->encode( $platform );
    close ANSIBLE_VARIABLES;
  

    my $playbook = $config->param('platform.ansible_playbook');
    # preserve colour for easy readability in head and tail
    # also save a copy without buffering (unlike tee) by using script -c
    # unfortunately, jenkins appears allergic to script -c (kills the script randomly while running), so switch back to tee
    open WRAPSCRIPT, '>', "$work_dir/wrapscript.$time.sh";
    say WRAPSCRIPT "#!/usr/bin/env bash";
    say WRAPSCRIPT "set -o errexit";
    say WRAPSCRIPT "export ANSIBLE_FORCE_COLOR=true";
    say WRAPSCRIPT "export ANSIBLE_HOST_KEY_CHECKING=False";
    say WRAPSCRIPT "ansible-playbook -v -i $work_dir/inventory $playbook --extra-vars \"\@$work_dir/variables.$time.json\" ";
    close (WRAPSCRIPT);

    my $command = "stdbuf -oL -eL bash $work_dir/wrapscript.$time.sh 2>&1 | tee $work_dir/ansible_run.$time.log";

    say "Ansible command: $command";
    system("chmod a+x $work_dir/wrapscript.$time.sh");

    return system($command);
}

sub run {
    my ($cmd, $hostname, $retries) = @_;

    if (!defined($retries) || $retries < 0) {
      $retries = 0;
    }

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
        while($retries >= 0) { 
          if (!system($final_cmd)) { last; }
          $retries--;
          sleep 10;
        }
        say 'launched machine!';
    }
    else {
        while($retries >=0) {
          
        if (!system($final_cmd)) { last; }
          $retries--;
          sleep 10;
        }
    }
}

1;
