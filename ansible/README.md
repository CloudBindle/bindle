capsid-vagrant
==============

Vagrant and associated deployment framework for CaPSID

The easiest way to use this is as follows:

```shell
$ vagrant up
```

This will start up a set of virtual machines for a small CaPSID cluster. 
At this stage, nothing yet has been provisioned, so nothing at all will
work. To provision, use:

```shell
$ ./deploy.sh
```

This currently works only with Virtualbox. 

seqware-bindle
==============

Note: You may need to turn off strict host key checking 
http://docs.ansible.com/intro_getting_started.html#host-key-checking

Use the regular Bindle to start VMs and then run the following script to generate an inventory file
   
   cp templates/sample_configs/vagrant_cluster_launch.blank.json.template vagrant_cluster_launch.json

Customize as needed, example with openstack in the root directory
   
   perl bin/launcher/launch_cluster.pl --use-openstack --working-dir target-os3
   bash bin/ansible-bridge/create_inventory.sh target-os3 > inventory
   ansible-playbook -v -i inventory ansible/seqware-install.yml 

This has been tested with Openstack with a two machine cluster

Override parameters (such as using build and install for SeqWare using git rather than artifactory in the following

   ansible-playbook -v -i inventory ansible/seqware-install.yml    --extra-vars "seqware_provider=git" 
   ansible-playbook -v -i inventory ansible/seqware-install.yml    --extra-vars "seqware_provider=git run_integration_tests=True" 
