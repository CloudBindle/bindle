Notes:

* the google doc for the end user release notes is: https://docs.google.com/document/d/12XTWk_zcQkManAXRaCOzlpIw4DIjE67jUhWX4HND2g4/edit

* setup your vagrant_cluster_launch.json based on the templates/sample_configs/vagrant_cluster_launch.dcc_validator.single.json.template
** you will want to pay close attention to '"DCC_VALIDATOR_DICTIONARY_SERVER": "hwww1-dcc.oicr.on.ca"' since that is the server that the VM will hit on every boot for a dictionary update

* ensure you are happy with the realm.ini passwords, see templates/dcc_validator/realm.ini

* launch the VirtualBox VM using:

 perl vagrant_cluster_launch.pl --use-virtualbox --working-dir target-vm --config-file vagrant_cluster_launch.json

* update the root password to match the VM release notes doc

* use "export appliance" in VirtualBox to make an OVA file

* upload (you can use the AWS web console) the OVA file to https://s3.amazonaws.com/oicr.vm/public/, once done make it "public", and copy the URL 

* update the VM release notes doc (for example, the S3 URL above), make a PDF, handoff to Hardeep
