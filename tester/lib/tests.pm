package tests;
use Net::OpenSSH;

sub test_cluster_as_ubuntu{
    my ($class,$ssh,$number_of_nodes) = @_;
    my $result = "";

    # check for gluster peers
    $result .= check_for_gluster_peers($ssh,$number_of_nodes);
    # check for gluster volumes
    $result .= check_for_gluster_volumes($ssh,$number_of_nodes);
    #TODO
    # run the seqware sanity check tool to see if seqware is working properly
    $result .= check_seqware_sanity($ssh);
    # check if helloworld workflow runs successfully
    #$result .= check_helloworld_workflow($ssh);

    return $result;
}

sub test_single_nodes_as_ubuntu{
    my ($class,$ssh) = @_;
    my $result = "";
   
    # run the seqware sanity check tool to see if seqware is working properly
    $result .= check_seqware_sanity($ssh);
    # check if helloworld workflow runs successfully
    $result .= check_helloworld_workflow($ssh);

    return $result;
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
    $ssh->system("sudo su - seqware -c 'cd jars;wget https://seqwaremaven.oicr.on.ca/artifactory/seqware-release/com/github/seqware/seqware-sanity-check/1.0.15/seqware-sanity-check-1.0.15-jar-with-dependencies.jar'");
    $ssh->error and die "Unable to get the seqware sanity check tool: ".$ssh->error;

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
    sleep 300;
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

1;
