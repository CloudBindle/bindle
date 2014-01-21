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

export HOST=`hostname`
echo master >> /var/lib/gridengine/default/common/act_qmaster

# restart
/etc/init.d/gridengine-exec stop
/etc/init.d/gridengine-exec start

# Not sure why, but the NFS mounts don't survive up to this point, try to remount them but don't fail if already present
mount %{MASTER_PIP}:/home /home || true
mount %{MASTER_PIP}:/usr/tmp/seqware-oozie /usr/tmp/seqware-oozie || true
mount %{MASTER_PIP}:/datastore /datastore || true
