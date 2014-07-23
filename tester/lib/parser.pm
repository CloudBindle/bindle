package parser;
use Config::Simple;
use autodie;
use common::sense;
use HTML::Manipulator;

sub update_matrix{
    my ($class,$html_doc,$json_file,$cloud_env,$result) = @_;
    $cloud_env = get_cloud_env($class,$cloud_env);
    $html_doc->replace("$json_file-$cloud_env" => {class => "success", _content => '<span class="glyphicon glyphicon-thumbs-up"> - PASS</span>'}) unless ($result =~ /FAIL/);
    return $html_doc;
}


sub set_test_result{
    my ($class, $html_doc, $env_file, $test_results) = @_;
    my $results_id = get_cloud_env($class,$env_file);
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
