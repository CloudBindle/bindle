## Manually Running Bindle Tester from scratch

Sometimes, a developer might want to run Bindle Tester to test the changed code on their local repository before pushing the code to the remote repository. This can waste a lot of time if they do it manually. However, now we have the Bindle Tester to do just this and at the end of the run, it will create a html file with the test results! This way, the developer can run the Bindle Tester overnight and in the morning, they would get the test results. Please note that the Bindle Tester takes about 1 hour to completely test a single node and multi-node cluster on one cloud environment. Let's get started with the steps one must take to manually run Bindle Tester without the use of Jenkins.

### Step 1 - Install Bindle Tester dependencies
You can install the dependencies through cpan:

    cpan install Net::OpenSSH
    cpan install HTML::Manipulator
    cpan install FileHandle
    cpan install File::Spec
    
To check to see if you have these, you can do:

    perl -c tester/bin/bindle_test_framework.pl
    
It should exit without any error messages.

### Step 2 - Setting up the Configuration Files

### Step 3 - Filling in the Configuration Files

### Step 4 - Running Bindle Tester

### Step 5 - Analyzing the Test Results


