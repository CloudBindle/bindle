use common::sense;
use Getopt::Long;
use IPC::System::Simple;
use Config::Simple;
use autodie;
use Data::Dumper;
use HTML::Manipulator::Document;
use FileHandle;
use Net::OpenSSH;
use FindBin qw($Bin);
use lib "$Bin/lib";
use tests;
use launch;
use parser;
# Testing
#my %options = (
 # user => 'ubuntu',
 # key_path => '/home/ubuntu/.ssh/ap-oicr-2.pem',
 # strict_mode => 0,
 # #master_opts => '-vvv',
 # master_opts => [-o => "StrictHostKeyChecking=no"]
#);
#my $ssh = connect_to_host('10.0.20.187','ubuntu','ap-oicr-2');
#my $res = test_cluster_as_ubuntu($ssh,2);
#my $res = tests->check_helloworld_workflow($ssh);
#$res .= test_cluster_as_seqware($ssh,2);
#die "$res";

#die "Testing";

my $bindle_folder_path = "";
my %cfg_path_files = (
			'tester/bindle_configs/openstack-toronto-old.cfg' => 'os',
			#'tester/bindle_configs/openstack-toronto-new.cfg' => 'os',
			#'bindle_configs/aws.cfg'  		   => 'aws',
                     );

my $html_doc = HTML::Manipulator::Document->from_file('tester/results.html');
GetOptions ("bindle-folder-path=s" => \$bindle_folder_path);

# goes through each environments and launches clusters and single node instances
while (my ($key,$value) = each(%cfg_path_files)){
    say "$key => $value";
    system("cp $key config/$value.cfg");
    
    # read in the cluster informations from the config file
    my $config_file = new Config::Simple("config/$value.cfg");
    
    # lauch the clusters
    my $test_results .= launch_clusters($config_file,$key);
    
    say "--------------------------------------------------------------------------------";
    my $environment = $config_file->param('platform.env');
    say "\tLAUNCHED ALL MULTINODE CLUSTERS FOR $environment";
    say "--------------------------------------------------------------------------------";

    #launch the single node clusters
    launch_single_nodes($config_file,$key);
    say "--------------------------------------------------------------------------------";
    say "\tLAUNCHED ALL SINGLE-NODE CLUSTERS FOR $environment";
    say "--------------------------------------------------------------------------------";   
    say "TEST RESULTS: $test_results";

    # record test results in html file
    my $results_id = parser->get_cloud_env($key);
    $html_doc->replace("$results_id-results" => {_content => "$test_results"});
}




#
$html_doc->save_as('tester/results1.html');
die "Testing";
#system("cp $cfg_path $bindle_folder_path/config/os.cfg");

# SUBROUTINES

sub launch_clusters{
    # launch the clusters
    my ($cfg_file,$env_file) = @_;
    my $result = "";
    my $cloud_env = parser->get_cloud_env($env_file);
    #$env_file = (split(/\//,$env_file))[-1];
    #$env_file = (split(/\./,$env_file))[0];

    my $platform = $cfg_file->param('platform.type');
    my $number_of_clusters = $cfg_file->param('platform.number_of_clusters');
    $platform = 'openstack' if ($platform == 'os');
        
    for (my $i = 1; $i <= $number_of_clusters; $i += 1){
        #system("perl bin/launcher/launch_cluster.pl --use-$platform --use-default-config --launch-cluster cluster$i");
        #my $json_file = $cfg_file->param("cluster$i.json_template_file_path");
        #$json_file = (split(/pancancer\./,$json_file))[1];
        # TODO: Need to implement a testing method to test the cluster!
	my $ssh = launch->connect_to_host(($cfg_file->param("cluster$i.floating_ips"))[0],$cfg_file->param('platform.ssh_key_name'));
        my $json_file = parser->get_json_file_name($cfg_file,"cluster$i");
        $result .= "\n<b>Configuration Profile: vagrant_cluster_launch.pancancer.$json_file</b>\n";
        $result .= tests->test_cluster_as_ubuntu($ssh,$cfg_file->param("cluster$i.number_of_nodes"));
        say "RESULTTTT: $result";
        say "ENV_FILE: $json_file-$cloud_env";
        $html_doc->replace("$json_file-$cloud_env" => {class => "success", _content => '<span class="glyphicon glyphicon-thumbs-up"> - PASS</span>'}) unless ($result =~ /FAIL/);
        say "--------------------------------------------------------------------------------";
        say "\tLaunched cluster: \n\tPLATFORM = $platform\n\t CLUSTER BLOCK = cluster$i";
        say "--------------------------------------------------------------------------------";
    }
    return $result;
}

sub launch_single_nodes{
    my ($cfg_file,$env_file) = @_;
    $env_file = (split(/\//,$env_file))[-1];
    $env_file = (split(/\./,$env_file))[0];
    my $platform = $cfg_file->param('platform.type');
    my $number_of_nodes = $cfg_file->param('platform.number_of_single_node_clusters');
    $platform = 'openstack' if ($platform == 'os');
    for (my $i = 1; $i <= $number_of_nodes; $i += 1){
        system("perl bin/launcher/launch_cluster.pl --use-$platform --use-default-config --launch-cluster singlenode$i");
        my $json_file = $cfg_file->param("singlenode$i.json_template_file_path");
        $json_file = (split(/pancancer\./,$json_file))[1];
        print "$json_file\n";
        #say "$json_file";

	#TODO: NEED TO IMPLEMENT A TESTING METHOD TO TEST THE NODE BEFORE PASSING IT!

        $html_doc->replace("$json_file-$env_file" => {class => "success", _content => '<span class="glyphicon glyphicon-thumbs-up"> - PASS</span>'});
        say "--------------------------------------------------------------------------------";
        say "\tLaunched cluster: \n\tPLATFORM = $platform\n\t CLUSTER BLOCK = cluster$i";
        say "--------------------------------------------------------------------------------";
    }
}


















































































































sub test_cluster_as_ubuntu{
    my ($ssh,$number_of_nodes) = @_;
    my $result = "";
    
    # check for gluster peers
    $result .= tests->check_for_gluster_peers($ssh,$number_of_nodes);
    # check for gluster volumes
    $result .= tests->check_for_gluster_volumes($ssh,$number_of_nodes);
    #TODO
    # run the seqware sanity check tool to see if seqware is working properly
    $result .= tests->check_seqware_sanity($ssh);
    # check if helloworld workflow runs successfully
    $result .= tests->check_helloworld_workflow($ssh);
    
    return $result;
}


sub test_single_nodes{

}

sub connect_to_host{
     my ($host, $user, $ssh_key_name) = @_;
     my %options = (
	user => "$user",
  	key_path => "/home/ubuntu/.ssh/$ssh_key_name.pem",
  	strict_mode => 0,
  	#master_opts => '-vvv',
  	master_opts => [-o => "StrictHostKeyChecking=no"]
     );

     system("rm -r ~/.ssh/known_hosts");
     print "Connecting to $host\n";
     
     my $ssh = Net::OpenSSH->new( $host, %options);
     $ssh->error and die "Couldn't establish SSH connection: ". $ssh->error;
     return $ssh;
}

sub check_for_gluster_peers{
    my ($ssh,$number_of_nodes) = @_;
    my $findings = "";
    # TEST FOR GLUSTER PEERS
    my $gluster_peers = $ssh->capture("sudo gluster peer status");
    $ssh->error and die "Gluster peers aren't set up: ".$ssh->error;
    my $failed = 0;
    for(my $i = 1; $i < $number_of_nodes; $i += 1){
        $failed = 1 unless ($gluster_peers =~ "worker$i");
    }
    
    if ($failed){
        $findings .= "FAIL: Gluster Peer status failed with the following output:\n$gluster_peers"; 
    }
    else{
        $findings .= "PASS: Gluster peers are properly connected!\n"
    }
    return $findings;
}

sub check_for_gluster_volumes{
    my ($ssh,$number_of_nodes) = @_;
    my $findings = "";
    # TEST FOR GLUSTER VOLUMES
    my $gluster_vol = $ssh->capture("sudo gluster volume status");
    $ssh->error and die "Gluster volumes aren't set up: ".$ssh->error;
    my $failed = 0;
    for(my $i = 1; $i < $number_of_nodes; $i += 1){
        $failed = 1 unless ($gluster_vol =~ "worker$i");
    }

    if ($failed){
        $findings .= "FAIL: Gluster Peer status failed with the following output:\n$gluster_vol";
    }
    else{
        $findings .= "PASS: Gluster volumes are set up successfully!\n";
    }
    return $findings;

}

sub check_seqware_sanity{
    my ($ssh) = @_;
    my $findings = "";
    
    # get the seqware sanity check tool
    #$ssh->system("sudo su - seqware -c 'cd jars;wget https://seqwaremaven.oicr.on.ca/artifactory/seqware-release/com/github/seqware/seqware-sanity-check/1.0.15/seqware-sanity-check-1.0.15-jar-with-dependencies.jar'");
    #$ssh->error and die "Unable to get the seqware sanity check tool: ".$ssh->error;
    
    if ($ssh->test("sudo su - seqware -c 'java -jar jars/seqware-sanity-check-1.0.15-jar-with-dependencies.jar'")){
        $findings .= "PASS: Seqware sanity check tool ran successfully!\n";
    }
    else{
	$findings .= "FAIL: Seqware Sanity check tool was unsuccessful!\n";
    }
    #$findings .= $ssh->capture("sudo su - seqware -c 'java -jar jars/seqware-sanity-check-1.0.15-jar-with-dependencies.jar'");
    $ssh->error and die "Unable to run the seqware sanity check tool: ".$ssh->error;
    
    return $findings;

}

sub check_helloworld_workflow{
    my ($ssh) = @_;
    my $findings = "";
    
    # launch the workflow, sleep for 10 minutes and then check the status of the workflow
    $ssh->system("sudo su - seqware -c 'seqware bundle launch --dir provisioned-bundles/Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_1.0.13/'");
    $ssh->error and die "Unable to launch the helloworld workflow: ".$ssh->error;
    sleep 600;
    $ssh->system("sudo su - seqware -c 'export OOZIE_URL=http://master:11000/oozie'");
    $ssh->error and die "Unable to export a variable: ".$ssh->error;
    
    my $workflow_result = $ssh->capture("sudo su - seqware -c 'export OOZIE_URL=http://master:11000/oozie;oozie jobs'");
    $ssh->error and die "Something might be wrong with oozie: ".$ssh->error;

    if ($workflow_result =~ "HelloWorld   SUCCEEDED"){
        $findings .= "PASS: Hello World workflow ran successfully!\n";
    }
    else{
        $findings .= "FAIL: Hello World Workflow Failed with the follwoing output: $workflow_result\n";
    }

    return $findings;
}
