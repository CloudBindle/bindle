package tests;
use Net::OpenSSH;

sub test_cluster_as_ubuntu{
    my ($class,$ssh,$number_of_nodes,$working_dir,$seq_version,$bwa_version) = @_;
    my $result = "";

    # check for gluster peers
    $result .= check_for_gluster_peers($ssh,$number_of_nodes,$working_dir);
    # check for gluster volumes
    $result .= check_for_gluster_volumes($ssh,$number_of_nodes,$working_dir);
    # check for SGE
    $result .= check_SGE_nodes($ssh,$number_of_nodes,$working_dir);
    # run the seqware sanity check tool to see if seqware is working properly
    $result .= check_seqware_sanity($ssh,$working_dir);
    # check if helloworld workflow runs successfully
    $result .= check_helloworld_workflow($ssh,$working_dir,$seq_version);
    # check if bwa workflow runs successfully
    $result .= check_bwa_workflow($ssh,$working_dir,3600,$seq_version,$bwa_version);

    return $result;
}

sub test_single_nodes_as_ubuntu{
    my ($class,$ssh,$working_dir,$seq_version,$bwa_version) = @_;
    my $result = "";
   
    # run the seqware sanity check tool to see if seqware is working properly
    $result .= check_seqware_sanity($ssh,$working_dir);
    # check if helloworld workflow runs successfully
    $result .= check_helloworld_workflow($ssh,$working_dir,$seq_version);
    # check if bwa workflow runs successfully
    $result .= check_bwa_workflow($ssh,$working_dir,3600,$seq_version,$bwa_version);

    return $result;
}

sub check_for_gluster_peers{
    my ($ssh,$number_of_nodes,$working_dir) = @_;
    my $findings = "";
    # TEST FOR GLUSTER PEERS
    my $failed = 0;
    my $gluster_peers = $ssh->capture("sudo gluster peer status");
    $failed = 1 if $ssh->error;
    for(my $i = 1; $i < $number_of_nodes; $i += 1){
        $failed = 1 unless ($gluster_peers =~ "worker$i");
    }
    
    if ($failed){
        $findings .= "FAIL: Gluster Peer status failed with the following output:\n$gluster_peers\n";
    }
    else{
        $findings .= "PASS: Gluster peers are properly connected!\n"
    }
    say "Tested gluster peers for $working_dir. The results are: \n\t$findings";
    return $findings;
}

sub check_for_gluster_volumes{
    my ($ssh,$number_of_nodes,$working_dir) = @_;
    my $findings = "";
    # TEST FOR GLUSTER VOLUMES
    my $failed = 0;
    my $gluster_vol = $ssh->capture("sudo gluster volume status");
    $failed = 1 if $ssh->error;
    system("echo '$gluster_vol' >> $working_dir/cluster.log");
    for(my $i = 1; $i < $number_of_nodes; $i += 1){
        $failed = 1 unless ($gluster_vol =~ "worker$i");
    }

    if ($failed){
        $findings .= "FAIL: Gluster Peer status failed with the following output:\n$gluster_vol\n";
    }
    else{
        $findings .= "PASS: Gluster volumes are set up successfully!\n";
    }
    say "Tested gluster volumes for $working_dir. The results are: \n\t$findings";
    return $findings;

}

sub check_SGE_nodes{
    my ($ssh, $number_of_nodes, $working_dir) = @_;
    my $findings = "";
    # Test to check if SGE is set up properly
    my $failed = 0;
    my $qhost_output = $ssh->capture("qhost");
    $failed = 1 if $ssh->error;
    system("echo '$qhost_output' >> $working_dir/cluster.log");
    for(my $i = 1; $i < $number_of_nodes; $i += 1){
        $failed = 1 unless ($qhost_output =~ /worker$i/);
    }

    if ($failed){
        $findings .= "FAIL: SGE isn't set up correctly: \n$qhost_output\n";
    } 
    else{
        $findings .= "PASS: SGE nodes are set up correctly (checked via qhost)!\n";
    }
    say "Tested SGE nodes for $working_dir. The results are: \n\t$findings";
    
    return $findings;
}

sub check_seqware_sanity{
    my ($ssh,$working_dir) = @_;
    my $findings = "";

    # get the seqware sanity check tool
    my $sanity_tool = $ssh->capture("sudo su - seqware -c 'cd jars;wget -q https://seqwaremaven.oicr.on.ca/artifactory/seqware-release/com/github/seqware/seqware-sanity-check/1.0.15/seqware-sanity-check-1.0.15-jar-with-dependencies.jar'");
    $ssh->error and return "FAIL: Unable to get the seqware sanity check tool: ".$ssh->error;
    system("echo '$sanity_tool' >> $working_dir/cluster.log");

    if ($ssh->test("sudo su - seqware -c 'java -jar jars/seqware-sanity-check-1.0.15-jar-with-dependencies.jar'")){
        $findings .= "PASS: Seqware sanity check tool ran successfully!\n";
    }
    else{
        $findings .= "FAIL: Seqware Sanity check tool was unsuccessful!\n";
    }
    $ssh->error and return "FAIL: Unable to run the seqware sanity check tool: ".$ssh->error;
    say "Tested seqware sanity check for $working_dir. The results are: \n\t$findings";

    return $findings;

}


sub check_helloworld_workflow{
    my ($ssh,$working_dir,$seq_version) = @_;
    my $findings = "";
    my $workflow_result = "";
 
    # launch the workflow; check if it succeeded by using oozie jobs
    my $workflow_launch = $ssh->capture("sudo su - seqware -c 'seqware bundle launch --dir provisioned-bundles/Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_$seq_version/'");
    $ssh->error and return "FAIL: Unable to launch the helloworld workflow: ".$ssh->error;
    $workflow_result .= $ssh->capture("sudo su - seqware -c 'export OOZIE_URL=http://master:11000/oozie;oozie jobs'");
    $ssh->error and return "FAIL: Something might be wrong with oozie: ".$ssh->error;
    
    # pass the output of "oozie jobs" into the log
    system("echo '$workflow_result' >> $working_dir/cluster.log");
    if ($workflow_result =~ "HelloWorld   SUCCEEDED"){
        $findings .= "PASS: Hello World workflow ran successfully!\n";
    }
    else{
        $findings .= "FAIL: Hello World Workflow Failed with the follwoing output: $workflow_result\n";
    }
    say "Tested helloworld workflow for $working_dir. The results are: \n\t$findings";

    return $findings;
}

sub check_bwa_workflow{
    my ($ssh,$working_dir,$time,$seq_version,$bwa_version) = @_;
    my $workflow_name = "Workflow_Bundle_BWA_$bwa_version\_SeqWare_$seq_version";
    
    # launch the workflow; check if it succeeded by using oozie jobs
    $ssh->capture("sudo su - seqware -c 'seqware bundle launch --dir provisioned-bundles/$workflow_name'");
    $ssh->error and return "FAIL: Unable to launch $workflow_name: ".$ssh_error;
    my $findings = "";
    my $workflow_result = "";
    $workflow_result = $ssh->capture("sudo su - seqware -c 'export OOZIE_URL=http://master:11000/oozie;oozie jobs'");
    $ssh->error and return "FAIL: Something went wrong with oozie: ",$ssh->error;
    
    # pass the output of "oozie jobs" into the log"
    system("echo '$workflow_result' >> $working_dir/cluster.log"); 
    if ($workflow_result =~ "BWA          SUCCEEDED"){
        $findings .= "PASS: $workflow_name ran successfully!\n";
    }
    else{
        $findings .= "FAIL: $workflow_name failed with the following output: $workflow_result\n";
    }
    say "Tested bwa workflow for $working_dir. The results are: \n\t$findings";

    return $findings;
}

1;
