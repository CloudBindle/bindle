package parser;
use Config::Simple;
use autodie;
use common::sense;
use HTML::Manipulator;
use Data::Dumper;
sub update_matrix{
    my ($class,$html_doc,$json_file,$cloud_env,$result) = @_;
    $cloud_env = get_cloud_env($class,$cloud_env);
    $html_doc->replace("$json_file-$cloud_env" => {class => "success", _content => '<span class="glyphicon glyphicon-thumbs-up"> - PASS</span>'}) unless ($result =~ /FAIL/);
    return $html_doc;
}

sub get_float_ip{
    my ($class,$working_directory,$node_name) = @_;
    my $float_ip = `cd $working_directory/$node_name; vagrant ssh-config`;
    $float_ip = (split(/HostName /,$float_ip))[1];
    $float_ip = (split(/\n/,$float_ip))[0];
    print Dumper($float_ip);
    return $float_ip;
}

sub set_test_result{
    my ($class, $html_doc, $env_file, $test_results) = @_;
    my $results_id = get_cloud_env($class,$env_file);

    my @json_templates = split(/<b>/,$test_results);
    for my $template (@json_templates){
        next if ($template eq '');
        my $temp_id = (split(/Configuration Profile: /,(split(/<\/b>/,$template))[0]))[1];
        if ($template =~ /FAIL/){
            $html_doc->replace("$temp_id-$results_id" => {class => "warning", _content => '<span class="glyphicon glyphicon-thumbs-down"> - FAIL</span>'})
        }
        else{
 	   $html_doc->replace("$temp_id-$results_id" => {class => "success", _content => '<span class="glyphicon glyphicon-thumbs-up"> - PASS</span>'})
        }

    }

    say "RESULT_ID: $results_id";
    $html_doc->replace("$results_id-results" => {_content => "$test_results"});
    return $html_doc;
}



sub get_json_file_name{
    my ($class,$config_file,$cluster_name) = @_;
    my $json_file = $config_file->param("$cluster_name.json_template_file_path");
    $json_file = (split(/pancancer\./,$json_file))[1];
    return $json_file;
}

sub get_cloud_env{
    my ($class,$env_file) = @_;
    $env_file = (split(/\//,$env_file))[-1];
    $env_file = (split(/\./,$env_file))[0];
    return $env_file;
}

1;
