package parser;
use Config::Simple;
use autodie;
use common::sense;
use HTML::Manipulator;
use Data::Dumper;
use File::Spec;

# update the test matrix for a particular configuration profile and environment
sub update_matrix{
    my ($class,$html_doc,$json_file,$cloud_env,$result) = @_;
    $cloud_env = get_cloud_env($class,$cloud_env);
    if ($result =~ /FAIL/){
	$html_doc->replace("$json_file-$cloud_env" => {class => "danger", _content => '<span class="glyphicon glyphicon-thumbs-down"> - FAIL</span>'});
    }
    else{
    	$html_doc->replace("$json_file-$cloud_env" => {class => "success", _content => '<span class="glyphicon glyphicon-thumbs-up"> - PASS</span>'});
    }
    return $html_doc;
}

# gets the floating ip for a node so that we can get the ssh access to it
sub get_float_ip{
    my ($class,$working_directory,$node_name) = @_;
    my $float_ip = `cd $working_directory/$node_name; vagrant ssh-config`;
    $float_ip = (split(/HostName /,$float_ip))[1];
    $float_ip = (split(/\n/,$float_ip))[0];
    print Dumper($float_ip);
    return $float_ip;
}

# record the results in text form for a particular environment
sub set_test_result{
    my ($class, $html_doc, $env_file, $test_results) = @_;
    my $results_id = get_cloud_env($class,$env_file);

    my @json_templates = split(/<b>/,$test_results);
    for my $template (@json_templates){
        next if ($template eq '');
        my $temp_id = (split(/Configuration Profile: /,(split(/<\/b>/,$template))[0]))[1];
        if ($template =~ /FAIL/){
            $html_doc->replace("$temp_id-$results_id" => {class => "danger", _content => '<span class="glyphicon glyphicon-thumbs-down"> - FAIL</span>'})
        }
        else{
 	   $html_doc->replace("$temp_id-$results_id" => {class => "success", _content => '<span class="glyphicon glyphicon-thumbs-up"> - PASS</span>'})
        }

    }

    say "RESULT_ID: $results_id";
    $html_doc->replace("$results_id-results" => {_content => "$test_results"});
    return $html_doc;
}

# gets most of the json file and this is used for id purposes when populating results.html  
sub get_json_file_name{
    my ($class,$config_file,$cluster_name) = @_;
    my $json_file = $config_file->param("$cluster_name.json_template_file_path");
    $json_file = (split(/pancancer\./,$json_file))[1];
    return $json_file;
}

# this will get us the platform we are working with(openstack-toronto-old) from the template_config path
sub get_cloud_env{
    my ($class,$env_file) = @_;
    $env_file = (split(/\//,$env_file))[-1];
    $env_file = (split(/\./,$env_file))[0];
    return $env_file;
}

# retreives all the target directories of a specific config file
# output is used for destroying clusters
sub get_cluster_dirs{
    my ($class,$config) = @_;
    my $cluster_blocks = "";
    my $number_of_single_nodes = $config->param('platform.number_of_single_node_clusters');
    my $number_of_clusters = $config->param('platform.number_of_clusters');
    for (my $i=1; $i <= $number_of_single_nodes; $i += 1){
        my $target_dir = $config->param("singlenode$i.target_directory");
        $cluster_blocks .= "$target_dir,";
    } 
    for (my $i=1; $i <= $number_of_clusters; $i += 1){
        my $target_dir = $config->param("cluster$i.target_directory");
        $cluster_blocks .= "$target_dir,";
    } 
    return $cluster_blocks;
}

sub get_rel_path{
   my ($class,$path) = @_;
   my $abs_path = `readlink -f $path`;
   $abs_path = (split(/\n/,$abs_path))[0];
   my $rel_path = File::Spec->abs2rel($abs_path,'.');
   return $rel_path
}

# returns a text with latest commits of Bindle, Seqware-bag, and Pancancer-bag
sub get_latest_commits{
  my ($class) = @_;
  my %paths;
  $paths{'Bindle'} = '.';
  $paths{'Seqware-bag'} = '../seqware-bag/';
  $paths{'Pancancer-bag'} = '../pancancer-bag/';
  my $all_commits = "<b>Latest Commits</b>";
  while ( my ($key, $value) = each(%paths) ) {
    if (-e $value){
       my $commit = `cd $value ; git log | head -n 1`;
       $commit = (split(' ',$commit))[1];
       $all_commits .= "\n$key: $commit";
    }
  }
  return $all_commits;
}

1;
