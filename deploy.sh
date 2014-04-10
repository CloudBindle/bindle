#!/usr/bin/env bash ansible-playbook -v -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
  --private-key=~/.vagrant.d/insecure_private_key \
  -u vagrant \
  global.yml
