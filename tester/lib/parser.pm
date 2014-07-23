package parser;
use Config::Simple;
use autodie;

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
