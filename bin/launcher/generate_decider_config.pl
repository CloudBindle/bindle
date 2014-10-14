#! /usr/bin/env perl

use common::sense;
use autodie;

use JSON;
use LibXML::Simple qw(:strict);

use Data::Dumper;

use Getopt::Long;
use File::Basename qw();

my $master_nodes;
GetOptions ( "ip-address=s" => \$master_nodes, );

die "Specify the file that contains the name and ip address of the SeqWare master node with plag ip-address"
        unless(defined $master_nodes);

open my $name_to_ipaddress, '<', $master_nodes;



my %clusters;

foreach (<$name_to_ipaddress>) {
    my ($host_name, $ip_address) = split "\t", $_;
    chomp $ip_address;
=head
    my $workflows_url = "http://$ip_address:8080/SeqWareWebService/workflows";
    my $workflows_xml = `curl -u admin\@admin.com:admin $workflows_url`;
print Dumper $workflows_xml;
die;
=cut
    $clusters{$host_name} =  { 
         "workflow_accession"      => "2",
         "username"                => 'admin@admin.com',
         "password"                => 'admin',
         "workflow_version"        => '2.6.0',
         "webservice"              => "http://$ip_address:8080/SeqWareWebService",
         "host"                    =>  'master',
         "max_workflows"           =>  '3',
         "max_scheduled_workflows" => '1'
    };
}

my $clusters_json = JSON->new->allow_nonref->pretty->encode(\%clusters);
print Dumper $clusters_json;
