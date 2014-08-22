## Manually Running Bindle Tester from scratch

Sometimes, a developer might want to run Bindle Tester to test the changed code on their local repository before pushing the code to the remote repository. This can waste a lot of time if they do it manually. However, now we have the Bindle Tester to do just this and at the end of the run, it will create a html file with the test results! This way, the developer can run the Bindle Tester overnight and in the morning, they would get the test results. Please note that the Bindle Tester takes about 1 hour to completely test a single node and multi-node cluster on one cloud environment. Let's get started with the steps you must take to manually run Bindle Tester without the use of Jenkins.

### Step 1 - Install Bindle Tester dependencies
You can install the dependencies through cpan:

    cpan install Net::OpenSSH
    cpan install HTML::Manipulator
    cpan install FileHandle
    cpan install File::Spec
    
To check to see if you have these, you can do:

    perl -c tester/bin/bindle_test_framework.pl
    
It should exit without any error messages. If not, download the perl modules that it is complaining about and please include it in the documentation.

### Step 2 - Setting up the Configuration Files
Bindle Tester currently supports AWS and OICR Openstack environments. So, you will find two configuration files located at tester/config_templates. Please note that you shouldn't be modifying these templates unless you want to add an extra parameter to it. Don't put any passwords or sensitive information in this file because we don't want anyone to be accidentally pushing that to GitHub. Assuming this is your first time using Bindle Tester, you should run the perl script which will copy all the config files over to ~/.bindle/test_framework_configs:

        perl tester/bin/bindle_test_framework.pl
        
You can now modify the config files at ~/.bindle/test_framework_configs since that is on your local machine and this way, it won't be accidentally pushed on github. You can fill in the configuration files by the following:

        # fill in the information for both the cloud environments 
        # there will be a config for vcloud once the test framework supports that as well
        vim ~/.bindle/test_framework_configs/aws.cfg
        vim ~/.bindle/test_framework_configs/openstack-toronto-new.cfg

Please note that if you add a parameter to test_framework_configs to the "platform" block, make sure to include the parameter in Bindle's config/ folder as well because it will throw an error stating that the parameters don't match! So, if you add a parameter in the tester config files, please change the other config files to include it as well. This feature is there to make sure that all the different configuration files for the same cloud environment have the same parameters to avoid confusion!

### Step 3 - Filling in the Configuration Files
For this tutorial, we want to launch clusters on aws. So, let's look at aws's configuration file:

        vim ~/.bindle/test_framework_configs/aws.cfg

To fill in the configuration files, most of the information needed to be filled in is the same as Bindle's configuration files. So, you should refer to Bindle's readme to fill the configuration in. I will go through the test framework specific parameters here:

        # seqware version and bwa workflow version should be the same version as 
        # the versions used by Bindle (currently its 1.0.15 and 2.6.0, respectively)
        seqware_version = 1.0.15
        bwa_workflow_version = 2.6.0
        # number of clusters should match the number of cluster blocks with more than one nodes
        # where the json_template_file_path parameter in that block is pointing to a "cluster" profile and not a "node" profile
        number_of_clusters = 1
        # number of single node clusters should match the number of single node blocks 
        # where the json_template_file_path parameter in that block is pointing to a "node" profile and not a "cluster" profile    
        number_of_single_node_clusters = 1

Also, when you are making cluster blocks, one thing to keep in minds is to always name your blocks by appending a number starting from 1 to "cluster" and "singlenode". For example, If you want to launch 4 clusters(2 multi-node and 2 single-node) in a cloud environment, then your cluster blocks should have the following headings: [cluster1], [cluster2], [singlenode1], and [singlenode2]. In this example, we want to launch one two-node cluster and one single-node cluster. This can be achieved by the adding the following blocks to the configuration file:

        [cluster1]
        number_of_nodes = 2
        target_directory = target-aws-1
        json_template_file_path = templates/sample_configs/vagrant_cluster_launch.pancancer.bwa_workflow.seqware.install.sge_cluster.json.template
        
        [singlenode1]
        number_of_nodes = 1
        target_directory = target-aws-3
        json_template_file_path = templates/sample_configs/vagrant_cluster_launch.pancancer.bwa_workflow.seqware.install.sge_node.json.template
        
Now, save this configuration file and we are ready to move on to the next step where we will be running the Bindle Tester!

### Step 4 - Running Bindle Tester
There are two parameter that you can use with tester/bindle_test_framework.pl script. The "--use-config-paths" parameter is required and we need to specify the paths of all the config templates we want to launch (ex. in our case it will be "~/.bindle/test_framework_configs/aws.cfg"). You can include more than one configuration file if you want to launch clusters on multiple cloud environments(both aws and OICR openstack) by adding a comma delimited list as an argument. The "--destroy-clusters" parameter simply destroys all the clusters that were launched and tested using this tool. Let's run the test framework which launches and tests clusters on aws only:

        # launch the test framework
        perl tester/bin/bindle_test_framework.pl --use-config-paths ~/.bindle/test_framework_configs/aws.cfg --destroy-clusters
Please note that if you don't want to terminate the clusters after Bindle Tester carries out the tests on the clusters, exclude the --destroy-clusters parameter.

### Next Steps - Analyzing the Test Results
Once Bindle Tester finishes, you can look at the test results located at tester/results.html. You might have to secure copy the file over from your launcher host to local machine so that you can use the web browser to view it. If you had the -destroy-clusters parameter set, you will still have your log files in the bindle directory located at "tmp<target_directory>". So, if anything went wrong and destroyed the clusters, you will still have access to your log files to determine the root cause of the problem. 

