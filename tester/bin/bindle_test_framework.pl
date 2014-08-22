BEGIN {push @INC, '~/perl5/lib/perl5'};
BEGIN {push @INC, '~/perl5/man/man3'};
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
use lib "$Bin/../lib";
use tests;
use launch;
use parser;
use threads;
use File::Spec;


my $config_paths = "";
my $html_doc = HTML::Manipulator::Document->from_file('tester/template.html');
my $help = 0;
my $destroy_clusters = 0;
my $exit_code = 0;
GetOptions ("use-config-paths=s" => \$config_paths,
            "destroy-clusters" => \$destroy_clusters,
            "help" => \$help);
if ($help){
    die "\n--------------------------------------------------------------------------------\nUSAGE: \n\t --use-config-paths <bindle_config file paths> Note: Pass in a list of bindle config paths relative to the bindle directory separated by comma(Ex. tester/bindle_configs/aws.cfg,tester/bindle_configs/vcloud.cfg\n\t--destory-clusters Note: Using this ensures that the clusters will be destroyed after the testing is finished. You should still check the web console to make sure that the clusters do get deleted. \n\t --help\n--------------------------------------------------------------------------------\n";
}

my %cfg_path_files = ();
my @config_path_files = split(/,/,$config_paths);

# hash to determine which config file to replace in the bindle folder
for my $config_path (@config_path_files){
    my $val = "";
    if ($config_path =~ /openstack/){
        $val = "os";
    }
    elsif ($config_path =~ /aws/){
        $val = "aws";
    }
    elsif ($config_path =~ /vcloud/){
        $val = "vcloud";
    }
    $cfg_path_files{"$config_path"} = $val;
}

# if ~/.bindle/test_framework_configs/ doesn't exist, 
# then tranfer all the .cfg files over from test/config_templates
my $abs_path = `readlink -f ~/.bindle/`;
$abs_path = (split(/\n/,$abs_path))[0];
my $rel_path = File::Spec->abs2rel($abs_path,'.');
if (not -e "$rel_path/test_framework_configs"){
    system("rsync -r config/* ~/.bindle/");    
    system("rsync -r tester/config_templates/* ~/.bindle/test_framework_configs"); 
    die "Copied the test_framework configs to ~/.bindle/test_framework_configs. Please fill in the desired config files and try again!";
}

# removes known_hosts because this causes issues with Net::OpenSSH
system("rm -r ~/.ssh/known_hosts");

# goes through each environments and launches clusters and single node instances
while (my ($key,$value) = each(%cfg_path_files)){

    # copy over the bindle configs from tester folder to bindle folder
    system("cp $key ~/.bindle/$value.cfg");

    # get the relative path of config file
    my $rel_path = parser->get_rel_path("~/.bindle/$value.cfg");    

    # read in the cluster information from config file
    my $config_file = new Config::Simple("$rel_path");
    
    # lauch the clusters
    my $test_results = launch_clusters($config_file,$key);    
    say "All the clusters have been launched and tested for $value! \nNow, generating an html document to show the test results!";
    if ($test_results =~ /FAIL/){
        $exit_code = 1;
    }
    
    # record test results in html file
    $html_doc = parser->set_test_result($html_doc,$key,$test_results);
    say "Test results have been generated for $value!";
    
    # destroy the clusters used for testing
    if ($destroy_clusters){
        say "Destroying all the clusters for $value!";
        my $cluster_blocks = parser->get_cluster_dirs($config_file);
        launch->destroy_clusters($cluster_blocks);
    }
}

# get all the commit SHA's for the repos if they exist (Bindle, seqware-bag, and pancancer-bag)
my $commit_SHAs = parser->get_latest_commits();
$html_doc->replace("other-info" => { _content => $commit_SHAs});

$html_doc->save_as('tester/results.html');
say "FINISHED: Saved the results to html page!";
exit $exit_code;








# SUBROUTINES

sub launch_clusters{
    my ($cfg_file,$env_file) = @_;
    my $result = "";
    my $platform = $cfg_file->param('platform.type');
    my $number_of_clusters = $cfg_file->param('platform.number_of_clusters');
    my $number_of_single_nodes = $cfg_file->param('platform.number_of_single_node_clusters');
    $platform = 'openstack' if ($platform eq 'OS');
    
    say "--------------------------------------------------------------------------------";
    my $environment = $cfg_file->param('platform.env');
    say "\tSTARTING TO LAUNCH ALL CLUSTERS FOR $environment";
    say "--------------------------------------------------------------------------------";
    # launch all the cluster blocks from a particular config file(ex. aws)
    $result .= launch_cluster_threads($number_of_clusters, $number_of_single_nodes, $platform,$cfg_file,$env_file,$result); 
    say "--------------------------------------------------------------------------------";
    say "\tLAUNCHED ALL CLUSTERS FOR $environment";
    say "--------------------------------------------------------------------------------";

    return $result;
}


sub launch_cluster_threads{
    my ($number_of_clusters,$number_of_nodes,$platform,$cfg_file,$env_file,$result) = @_;
    
    my %threads;
    
    # create threads for all the multi-node cluster blocks 
    for (my $i = 1; $i <= $number_of_clusters; $i += 1){
         say "STARTING A THREAD TO LAUNCH CLUSTERS FOR $env_file,cluster$i";
         my $cluster_name = "cluster$i";
         my $thr = threads->create(\&launch_one_cluster,$number_of_clusters,$platform,$cfg_file,$env_file,$result,$cluster_name);
         $threads{"cluster$i"} = $thr;
         sleep 60;
    }

    # create threads for all the single-node cluster blocks 
    for (my $i = 1; $i <= $number_of_nodes; $i += 1){
        my $node_name = "singlenode$i";
        say "STARTING A THREAD TO LAUNCH SINGLE NODE CLUSTERS FRO $env_file, singlenode$i";
        my $thr = threads->create(\&launch_one_cluster,$number_of_nodes,$platform,$cfg_file,$env_file,$result,$node_name);
        $threads{"$node_name"} = $thr;
        sleep 60;
    }
    say " ALL LAUNCH THREADS STARTED";
    print Dumper(%threads);

    # join all the threads to produce a result for a particular config file(aws.cfg)
    while (my ($key,$value) = each(%threads)){
        $result .= $value->join();
    }

    say "ALL LAUNCH THREADS COMPLETED FOR $env_file";
    return $result;
}


sub launch_one_cluster{
        my ($number_of_clusters,$platform,$cfg_file,$env_file,$result,$cluster_name) = @_;
        my $working_dir = $cfg_file->param("$cluster_name.target_directory");
        my $seq_version = $cfg_file->param("platform.seqware_version");
        my $bwa_version = $cfg_file->param("platform.bwa_workflow_version");
        system("mkdir $working_dir");
        
        # launch the cluster via bindle
        system("perl bin/launcher/launch_cluster.pl --use-$platform --use-default-config --launch-cluster $cluster_name >> $working_dir/cluster.log");
        
        # archiving the log files (cluster.log,master.log, and worker.log)
        if (not $destroy_clusters){
            system("mkdir tmp$working_dir") unless (-e "tmp$working_dir");
            system("cp $working_dir/*.log tmp$working_dir/");  
        }

        # ssh into the master node and test if bindle was provisioned properly
        my $float_ip = parser->get_float_ip($cfg_file->param("$cluster_name.target_directory"),"master");
        say "FLOATIP: $float_ip";
        my $ssh = launch->connect_to_host($float_ip,$cfg_file->param('platform.ssh_key_name'));
        my $json_file = parser->get_json_file_name($cfg_file,"$cluster_name");
        $result .= "\n<b>Configuration Profile: vagrant_cluster_launch.pancancer.$json_file</b>\n";
        if ($cluster_name =~ /cluster/){
            $result .= tests->test_cluster_as_ubuntu($ssh,$cfg_file->param("$cluster_name.number_of_nodes"),$working_dir,$seq_version,$bwa_version);
        }
	else{
	    $result .= tests->test_single_nodes_as_ubuntu($ssh,$working_dir,$seq_version,$bwa_version);
        }

        # record the result in the matrix
        $html_doc = parser->update_matrix($html_doc,$json_file,$env_file,$result);
        say "\n--------------------------------------------------------------------------------";
        say "\tLaunched cluster: \n\tPLATFORM = $platform\n\t CLUSTER BLOCK = $cluster_name";
        say "--------------------------------------------------------------------------------";
        say "RESULT: $result";
        
        return $result;
}

