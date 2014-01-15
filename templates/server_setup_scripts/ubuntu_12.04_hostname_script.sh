#!/bin/bash -vx

# setup hosts
# NOTE: the hostname seems to already be set at least on BioNimubs OS
echo '%{HOSTS}' >> /etc/hosts
hostname %{HOST}
