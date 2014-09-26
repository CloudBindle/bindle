package cluster::inventory;

use common::sense;
use autodie qw(:all);

my $inventory_file_config_key = "HOST_INVENTORY_FILE_PATH";

sub write_inventory_header{
    my ($class, $configs, $cluster_name) = @_;
    print "Here";
    print "In inventory: $configs->{'HOST_INVENTORY_FILE_PATH'}\n";
    my $filename = $configs->{$inventory_file_config_key};
    open(my $fh, '>>', $filename) or die "Could not open file $filename $!";
    say $fh "[$cluster_name]";
    close $fh;
}

sub add_node_to_inventory{
    my ($class, $configs, $cluster_name, $node_name, $node_ip) = @_;
    my $filename = $configs->{$inventory_file_config_key};
    open(my $fh, '>>', $filename) or die "Could not open file $filename $!";
    say $fh "$cluster_name-$node_name ansible_ssh_host=$node_ip";
    close $fh;
}


sub add_master_ip_to_master_list{
    my ($class, $configs, $cluster_name, $node, $node_ip) = @_;
    my $filename = $configs->{$inventory_file_config_key};
    my $data = "";

    if (-e $filename){
        open my $fh, "<$filename" or die "error opening file: $filename $!";
        $data = do { local $/; <$fh> };
        close $fh;
    }
    my $found = ($data=~s/\[all-masters]/[all-masters]\n$cluster_name-$node ansible_ssh_host=$node_ip/mi);
    if (!$found){
        $data = $data."[all-masters]\n$cluster_name-$node ansible_ssh_host=$node_ip\n";
    }
    
    open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
    print $fh $data;
    close $fh;

} 

sub create_inventory_file_from_scratch{


}
