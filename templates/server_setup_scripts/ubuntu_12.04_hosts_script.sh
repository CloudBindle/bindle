#!/bin/bash -vx

# hosts
# setup hostname
hostname %{HOST}

# setup /etc/hosts
# fix the /etc/hosts file since SGE wants reverse lookup to work
cp /etc/hosts /tmp/hosts
echo '127.0.0.1 localhost' > /etc/hosts
echo `/sbin/ifconfig  | grep -A 3 eth0 | grep 'inet addr' | perl -e 'while(<>){ chomp; /inet addr:(\d+\.\d+\.\d+\.\d+)/; print $1; }'` `hostname` >> /etc/hosts
cat /tmp/hosts | grep -v '127.0.1.1' | grep -v `hostname` | grep -v localhost | >> /etc/hosts

# setup hosts
# NOTE: the hostname seems to already be set at least on BioNimubs OS
echo '%{HOSTS}' >> /etc/hosts

