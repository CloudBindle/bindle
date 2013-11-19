#!/bin/bash

# see http://helms-deep.cable.nu/~rwh/blog/?p=159
# you would test this by (as seqware) doing:
# "echo hostname | qsub -cwd
# watch qstat -f"
# you should then see your job run and also see STDIN.* files get created with the hostname in them

# first, fix the /etc/hosts file since SGE wants reverse lookup to work
cp /etc/hosts /tmp/hosts
echo `/sbin/ifconfig  | grep -A 3 eth0 | grep 'inet addr' | perl -e 'while(<>){ chomp; /inet addr:(\d+\.\d+\.\d+\.\d+)/; print $1; }'` `hostname` > /etc/hosts
cat /tmp/hosts | grep -v '127.0.1.1' >> /etc/hosts

# setup hosts
# NOTE: the hostname seems to already be set at least on BioNimubs OS
echo '%{HOSTS}' >> /etc/hosts
hostname  $HOST

# get packages
apt-get update
export DEBIAN_FRONTEND=noninteractive
apt-get -q -y --force-yes install gridengine-client gridengine-common gridengine-exec 

# restart
/etc/init.d/gridengine-exec stop
/etc/init.d/gridengine-exec start

# configure
export HOST=`hostname`
sudo -u sgeadmin qconf -am seqware
qconf -au seqware users

qconf -ah $HOST 

qconf -ahgrp @allhosts
# might need to do this instead
qconf -mhgrp @allhosts

# config
qconf -aattr hostgroup hostlist $HOST @allhosts

# interactive
# uses the same editor as above
qconf -aq main.q
# same as above, may need to modify the queue instead
qconf -mq main.q

qconf -aattr queue hostlist @allhosts main.q

qconf -aattr queue slots "[$HOST=1]" main.q

# restart
/etc/init.d/gridengine-exec stop
/etc/init.d/gridengine-exec start

