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
    $html_doc = parser->set_test_result($html_doc,$key,$test_results);
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
    my $platform = $cfg_file->param('platform.type');
    my $number_of_clusters = $cfg_file->param('platform.number_of_clusters');
    $platform = 'openstack' if ($platform == 'os');
        
    for (my $i = 1; $i <= $number_of_clusters; $i += 1){
        #system("perl bin/launcher/launch_cluster.pl --use-$platform --use-default-config --launch-cluster cluster$i");
	
        my $ssh = launch->connect_to_host(($cfg_file->param("cluster$i.floating_ips"))[0],$cfg_file->param('platform.ssh_key_name'));
        my $json_file = parser->get_json_file_name($cfg_file,"cluster$i");
        $result .= "\n<b>Configuration Profile: vagrant_cluster_launch.pancancer.$json_file</b>\n";
        $result .= tests->test_cluster_as_ubuntu($ssh,$cfg_file->param("cluster$i.number_of_nodes"));
        
        # record the result in the matrix
        $html_doc = parser->update_matrix($html_doc,$json_file,$env_file,$result);
        say "RESULTTTT: $result";
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
