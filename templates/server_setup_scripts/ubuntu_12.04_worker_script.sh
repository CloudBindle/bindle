#!/bin/bash -vx

# general apt-get
apt-get update
export DEBIAN_FRONTEND=noninteractive

# common installs for master and workers
apt-get -q -y --force-yes install git maven sysv-rc-conf xfsprogs
apt-get -q -y --force-yes install hadoop-0.20-mapreduce-tasktracker hadoop-hdfs-datanode hadoop-client hbase-regionserver

usermod -a -G seqware mapred
usermod -a -G mapred seqware

# setup the HDFS drives
# TODO
###perl /vagrant/setup_hdfs_volumes.pl

# configuration for hadoop
cp /vagrant/conf.worker.tar.gz /etc/hadoop/
cd /etc/hadoop/
tar zxf conf.worker.tar.gz
cd -
update-alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.my_cluster 50
update-alternatives --set hadoop-conf /etc/hadoop/conf.my_cluster

# hdfs config
# should setup multiple directories in hdfs-site.xml
# TODO: this assumes /mnt has the ephemeral drive!
ln -s /mnt /data
mkdir -p /data/1/dfs/nn /data/1/dfs/dn
chown -R hdfs:hdfs /data/1/dfs/nn /data/1/dfs/dn
chmod 700 /data/1/dfs/nn /data/1/dfs/dn
mkdir -p /data/1/mapred/local
chown -R mapred:mapred /data/1/mapred

# start all the hadoop daemons
for x in `cd /etc/init.d ; ls hadoop-hdfs-*` ; do sudo service $x start ; done

# start mapred
for x in `cd /etc/init.d ; ls hadoop-0.20-mapreduce-*` ; do sudo service $x start ; done

# TODO: probably need to have multiple zookeepers running
# setup hbase
# TODO: need hdfs-site.xml configured properly using alternatives, but for now just copy it
cp /etc/hadoop/conf/hbase-site.xml /etc/hbase/conf/hbase-site.xml
service hbase-regionserver start

# setup daemons to start on boot
for i in cron hadoop-hdfs-datanode hadoop-0.20-mapreduce-tasktracker; do echo $i; sysv-rc-conf $i on; done

# setup NFS
# seqware tutorials
apt-get -q -y --force-yes install rpcbind nfs-common
mkdir -p /usr/tmp/seqware-oozie
mkdir -p /datastore
echo 'rpcbind : ALL' >> /etc/hosts.deny
echo 'rpcbind : %{MASTER_PIP}' >> /etc/hosts.allow
mount %{MASTER_PIP}:/home /home
mount %{MASTER_PIP}:/usr/tmp/seqware-oozie /usr/tmp/seqware-oozie
mount %{MASTER_PIP}:/datastore /datastore

chmod a+rwx /home
chmod a+rwx /usr/tmp/seqware-oozie
chmod a+rwx /datastore


# add seqware user
# seems duplicated from minimal script
# useradd -d /home/seqware -m seqware -s /bin/bash

# not sure if this is required
mkdir -p /tmp/hadoop-mapred
chown mapred:mapred /tmp/hadoop-mapred
chmod -R a+rwx /tmp/hadoop-mapred

# Add hadoop-init startup script
cp /vagrant/hadoop-init-worker /etc/init.d/hadoop-init
chown root:root /etc/init.d/hadoop-init
chmod 755 /etc/init.d/hadoop-init
sysv-rc-conf hadoop-init on

