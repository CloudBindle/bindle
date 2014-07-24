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
use threads;

my $bindle_folder_path = "";
my %cfg_path_files = (
			'tester/bindle_configs/openstack-toronto-old.cfg' => 'os',
			#'tester/bindle_configs/openstack-toronto-new.cfg' => 'os',
			#'bindle_configs/aws.cfg'  		   => 'aws',
                     );

my $html_doc = HTML::Manipulator::Document->from_file('tester/template.html');
GetOptions ("bindle-folder-path=s" => \$bindle_folder_path);

#my %threads = {};
# goes through each environments and launches clusters and single node instances
while (my ($key,$value) = each(%cfg_path_files)){
    say "$key => $value";
    #say "STARTING A THREAD TO LAUNCH CLUSTERS FOR $key";
    #my $thr = threads->create(\&launch_clusters,$config_file,$key);
    #$threads{$key} = $thr;

    system("cp $key config/$value.cfg");
    
    # read in the cluster informations from the config file
    my $config_file = new Config::Simple("config/$value.cfg");
    
    # lauch the clusters
    my $test_results = launch_clusters($config_file,$key);    

    # record test results in html file
    $html_doc = parser->set_test_result($html_doc,$key,$test_results);
}

$html_doc->save_as('tester/results.html');
die "Testing";








# SUBROUTINES

sub launch_clusters{
    # launch the clusters
    my ($cfg_file,$env_file) = @_;
    my $result = "";
    my $platform = $cfg_file->param('platform.type');
    my $number_of_clusters = $cfg_file->param('platform.number_of_clusters');
    my $number_of_single_nodes = $cfg_file->param('platform.number_of_single_node_clusters');
    $platform = 'openstack' if ($platform == 'os');
    


    # launch all the multinode cluster for a particular cloud environment (ex. aws)
    $result .= launch_multi_node_clusters($number_of_clusters, $platform,$cfg_file,$env_file,$result); 
    say "--------------------------------------------------------------------------------";
    my $environment = $cfg_file->param('platform.env');
    say "\tLAUNCHED ALL MULTINODE CLUSTERS FOR $environment";
    say "--------------------------------------------------------------------------------";

    # launch all the single node clusters for a particular cloud environment (ex. aws)
    #$result .= launch_single_node_clusters($number_of_single_nodes, $platform, $cfg_file, $env_file,$result);
    say "--------------------------------------------------------------------------------";
    say "\tLAUNCHED ALL SINGLE-NODE CLUSTERS FOR $environment";
    say "--------------------------------------------------------------------------------";

    return $result;
}


sub launch_multi_node_clusters{
    my ($number_of_clusters,$platform,$cfg_file,$env_file,$result) = @_;


    my %threads = {};
    for (my $i = 1; $i <= $number_of_clusters; $i += 1){
         say "STARTING A THREAD TO LAUNCH CLUSTERS FOR $env_file,cluster$i";
         my $cluster_name = "cluster$i";
         my $thr = threads->create(\&launch_multi_node_cluster,$number_of_clusters,$platform,$cfg_file,$env_file,$result,$cluster_name);
         $threads{"cluster$i"} = $thr;
         sleep 30;
       # system("perl bin/launcher/launch_cluster.pl --use-$platform --use-default-config --launch-cluster cluster$i");
       # my $float_ip = parser->get_float_ip($cfg_file->param("cluster$i.target_directory"),"master.log");
       # my $ssh = launch->connect_to_host($float_ip,$cfg_file->param('platform.ssh_key_name'));
       # my $json_file = parser->get_json_file_name($cfg_file,"cluster$i");
       # $result .= "\n<b>Configuration Profile: vagrant_cluster_launch.pancancer.$json_file</b>\n";
       # $result .= tests->test_cluster_as_ubuntu($ssh,$cfg_file->param("cluster$i.number_of_nodes"));

        # record the result in the matrix
       # $html_doc = parser->update_matrix($html_doc,$json_file,$env_file,$result);
       # say "RESULT: $result";
       # say "--------------------------------------------------------------------------------";
       # say "\tLaunched cluster: \n\tPLATFORM = $platform\n\t CLUSTER BLOCK = cluster$i";
       # say "--------------------------------------------------------------------------------";
    }
    say " ALL LAUNCH THREADS STARTED";

    for (my $k = 1; $k <= $number_of_clusters; $k += 1){
        $result .= $threads{"cluster$k"}->join();
    }
    return $result;
}

sub launch_multi_node_cluster{
        my ($number_of_clusters,$platform,$cfg_file,$env_file,$result,$cluster_name) = @_;
        my $working_dir = $cfg_file->param("$cluster_name.target_directory");
        system("mkdir $working_dir");
        system("perl bin/launcher/launch_cluster.pl --use-$platform --use-default-config --launch-cluster $cluster_name >> $working_dir/cluster.log");
        my $float_ip = parser->get_float_ip($cfg_file->param("$cluster_name.target_directory"),"master.log");
        my $ssh = launch->connect_to_host($float_ip,$cfg_file->param('platform.ssh_key_name'));
        my $json_file = parser->get_json_file_name($cfg_file,"$cluster_name");
        $result .= "\n<b>Configuration Profile: vagrant_cluster_launch.pancancer.$json_file</b>\n";
        $result .= tests->test_cluster_as_ubuntu($ssh,$cfg_file->param("$cluster_name.number_of_nodes"));

        # record the result in the matrix
        $html_doc = parser->update_matrix($html_doc,$json_file,$env_file,$result);
        say "RESULT: $result";
        say "--------------------------------------------------------------------------------";
        say "\tLaunched cluster: \n\tPLATFORM = $platform\n\t CLUSTER BLOCK = $cluster_name";
        say "--------------------------------------------------------------------------------";
	return $result;
}

sub launch_single_node_clusters{
    my ($number_of_single_nodes,$platform,$cfg_file,$env_file,$result) = @_;
    for (my $i = 1; $i <= $number_of_single_nodes; $i += 1){
        system("perl bin/launcher/launch_cluster.pl --use-$platform --use-default-config --launch-cluster singlenode$i");
        
        my $float_ip = parser->get_float_ip($cfg_file->param("singlenode$i.target_directory"),"master.log");
        my $ssh = launch->connect_to_host($float_ip,$cfg_file->param('platform.ssh_key_name'));

        my $json_file = parser->get_json_file_name($cfg_file,"singlenode$i");
        $result .= "\n<b>Configuration Profile: vagrant_cluster_launch.pancancer.$json_file</b>\n";
        $result .= tests->test_single_nodes_as_ubuntu($ssh);

        # record the result in the matrix
        $html_doc = parser->update_matrix($html_doc,$json_file,$env_file,$result);
        say "RESULT: $result";
        say "--------------------------------------------------------------------------------";
        say "\tLaunched Single Node Cluster: \n\tPLATFORM = $platform\n\t CLUSTER BLOCK = singlenode$i";
        say "--------------------------------------------------------------------------------";
    }
    return $result;
}
