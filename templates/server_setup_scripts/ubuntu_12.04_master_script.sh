#!/bin/bash -vx

# first, set the hostname
hostname master

# fix the /etc/hosts file since SGE wants reverse lookup to work
cp /etc/hosts /tmp/hosts
echo `/sbin/ifconfig  | grep -A 3 eth0 | grep 'inet addr' | perl -e 'while(<>){ chomp; /inet addr:(\d+\.\d+\.\d+\.\d+)/; print $1; }'` `hostname` > /etc/hosts
cat /tmp/hosts | grep -v '127.0.1.1' >> /etc/hosts

# setup hosts
# NOTE: the hostname seems to already be set at least on BioNimubs OS
echo '%{HOSTS}' >> /etc/hosts

# general apt-get
apt-get update
export DEBIAN_FRONTEND=noninteractive

# common installs for master and workers
apt-get -q -y --force-yes install git maven sysv-rc-conf xfsprogs
apt-get -q -y --force-yes install hadoop-0.20-mapreduce-tasktracker hadoop-hdfs-datanode hadoop-client hbase-regionserver

usermod -a -G seqware mapred
usermod -a -G mapred seqware

# setup zookeeper
apt-get -q -y --force-yes install zookeeper zookeeper-server
service zookeeper-server init
service zookeeper-server start

# install Hadoop deps, the master node runs the NameNode, SecondaryNameNode and JobTracker
# NOTE: shouldn't really use secondary name node on same box for production
apt-get -q -y --force-yes install hadoop-0.20-mapreduce-jobtracker hadoop-hdfs-namenode hue hue-server hue-plugins hue-oozie oozie oozie-client hbase hbase-master hbase-thrift

# the repos have been setup in the minimal script
apt-get -q -y --force-yes install postgresql-client-9.1 tomcat6-common tomcat6 apache2

# setup LZO
#wget -q http://archive.cloudera.com/gplextras/ubuntu/lucid/amd64/gplextras/cloudera.list
#mv cloudera.list /etc/apt/sources.list.d/gplextras.list
#apt-get update
#apt-get -q -y --force-yes install hadoop-lzo-cdh4

# configuration for hadoop
cp /vagrant/conf.master.tar.gz /etc/hadoop/
cd /etc/hadoop/
tar zxf conf.master.tar.gz
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

# format HDFS
sudo -u hdfs hadoop namenode -format -force

# setup the HDFS drives
# TODO: this perl script should do all of the above
#perl /vagrant/setup_hdfs_volumes.pl

# start all the hadoop daemons
for x in `cd /etc/init.d ; ls hadoop-hdfs-*` ; do sudo service $x start ; done

# setup various HDFS directories
sudo -u hdfs hadoop fs -mkdir /tmp 
sudo -u hdfs hadoop fs -chmod -R 1777 /tmp
sudo -u hdfs hadoop fs -mkdir -p /var/lib/hadoop-hdfs/cache/mapred/mapred/staging
sudo -u hdfs hadoop fs -chmod 1777 /var/lib/hadoop-hdfs/cache/mapred/mapred/staging
sudo -u hdfs hadoop fs -chown -R mapred /var/lib/hadoop-hdfs/cache/mapred
sudo -u hdfs hadoop fs -mkdir /tmp/mapred/system
sudo -u hdfs hadoop fs -chown mapred:hadoop /tmp/mapred/system
sudo -u hdfs hadoop fs -mkdir -p /tmp/hadoop-mapred/mapred
sudo -u hdfs hadoop fs -chmod -R a+wrx /tmp/hadoop-mapred/mapred
mkdir -p /tmp/hadoop-mapred
chown mapred:mapred /tmp/hadoop-mapred
chmod -R a+rwx /tmp/hadoop-mapred

# start mapred
for x in `cd /etc/init.d ; ls hadoop-0.20-mapreduce-*` ; do sudo service $x start ; done

# setup hue
cd /usr/share/hue
cp desktop/libs/hadoop/java-lib/hue-plugins-*.jar /usr/lib/hadoop-0.20-mapreduce/lib
cd -
# for some reason needs to be restarted to register plugins properly
service hue stop
service hue start

# setup Oozie
sudo -u oozie /usr/lib/oozie/bin/ooziedb.sh create -run
wget -q http://extjs.com/deploy/ext-2.2.zip
unzip ext-2.2.zip
mv ext-2.2 /var/lib/oozie/

# we used to setup the postgres database here
# instead, call the ubuntu_12.04_dbserver_script before this 

perl -pi -e  "s/org.apache.derby.jdbc.EmbeddedDriver/org.postgresql.Driver/;" oozie-site.xml
perl -pi -e "s/jdbc:derby:.*create=true/jdbc:postgresql:\/\/%{SEQWARE_DB_SERVER}:5432\/oozie/;" oozie-site.xml
perl -0pi -e "s/<name>oozie.service.JPAService.jdbc.username<\/name>[.\s]*<value>sa<\/value>/<name>oozie.service.JPAService.jdbc.username<\/name><value>oozie<\/value>/;" oozie-site.xml
perl -0pi -e "s/<name>oozie.service.JPAService.jdbc.password<\/name>[.\s]*<value> <\/value>/<name>oozie.service.JPAService.jdbc.password<\/name><value>oozie<\/value>/;" oozie-site.xml
# this requires that postgres is running, so the db script needs to run first
sudo -u oozie /usr/lib/oozie/bin/ooziedb.sh create -run

service oozie start

# setup hbase
# TODO: need hdfs-site.xml configured properly using alternatives, but for now just copy it
cp /etc/hadoop/conf/hbase-site.xml /etc/hbase/conf/hbase-site.xml
sudo -u hdfs hadoop fs -mkdir /hbase
sudo -u hdfs hadoop fs -chown hbase /hbase
service hbase-master start
service hbase-regionserver start

service hue restart

# setup daemons to start on boot
# this used to also setup tomcat, instead call wserver_script first
for i in apache2 cron hadoop-hdfs-namenode hadoop-hdfs-datanode hadoop-hdfs-secondarynamenode hadoop-0.20-mapreduce-tasktracker hadoop-0.20-mapreduce-jobtracker hue oozie postgresql hbase-master hbase-regionserver; do echo $i; sysv-rc-conf $i on; done

# configure dirs for seqware
mkdir -p /usr/tmp/seqware-oozie 
chmod -R a+rwx /usr/tmp/
chown -R seqware:seqware /usr/tmp/seqware-oozie

sudo mkdir /datastore
sudo chown seqware:seqware /datastore
sudo chmod 774 /datastore

## Setup NFS before seqware
# see https://help.ubuntu.com/community/SettingUpNFSHowTo#NFS_Server
apt-get -q -y --force-yes install rpcbind nfs-kernel-server
echo '%{EXPORTS}' >> /etc/exports
exportfs -ra
# TODO: get rid of portmap localhost setting maybe... don't see the file they refer to
service portmap restart
service nfs-kernel-server restart

# Add hadoop-init startup script
cp /vagrant/hadoop-init-master /etc/init.d/hadoop-init
chown root:root /etc/init.d/hadoop-init
chmod 755 /etc/init.d/hadoop-init
sysv-rc-conf hadoop-init on
