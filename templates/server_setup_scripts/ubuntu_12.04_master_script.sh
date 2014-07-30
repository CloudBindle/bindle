#!/bin/bash -vx

# general apt-get
apt-get update
export DEBIAN_FRONTEND=noninteractive

# common installs for master and workers
apt-get -q -y --force-yes install git maven sysv-rc-conf xfsprogs curl
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
apt-get -q -y --force-yes install postgresql-9.1 postgresql-client-9.1 tomcat7-common tomcat7 apache2

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
cd /tmp
wget -q http://extjs.com/deploy/ext-2.2.zip
unzip ext-2.2.zip
mv ext-2.2 /var/lib/oozie/
cd -

# setup oozie with postgres
sudo -u postgres psql --command "CREATE ROLE oozie LOGIN ENCRYPTED PASSWORD 'oozie' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
sudo -u postgres psql --command "CREATE DATABASE oozie WITH OWNER = oozie ENCODING = 'UTF-8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "host    oozie         oozie         0.0.0.0/0             md5" >> /etc/postgresql/9.1/main/pg_hba.conf
sudo -u postgres /usr/lib/postgresql/9.1/bin/pg_ctl reload -s -D /var/lib/postgresql/9.1/main
perl -pi -e "s/org.apache.derby.jdbc.EmbeddedDriver/org.postgresql.Driver/;" /etc/oozie/conf/oozie-site.xml
perl -pi -e "s/jdbc:derby:.*create=true/jdbc:postgresql:\/\/localhost:5432\/oozie/;" /etc/oozie/conf/oozie-site.xml
perl -0pi -e "s/<name>oozie.service.JPAService.jdbc.username<\/name>[.\s]*<value>sa<\/value>/<name>oozie.service.JPAService.jdbc.username<\/name><value>oozie<\/value>/;" /etc/oozie/conf/oozie-site.xml
perl -0pi -e "s/<name>oozie.service.JPAService.jdbc.password<\/name>[.\s]*<value> <\/value>/<name>oozie.service.JPAService.jdbc.password<\/name><value>oozie<\/value>/;" /etc/oozie/conf/oozie-site.xml
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
for i in apache2 cron hadoop-hdfs-namenode hadoop-hdfs-datanode hadoop-hdfs-secondarynamenode hadoop-0.20-mapreduce-tasktracker hadoop-0.20-mapreduce-jobtracker hue oozie postgresql tomcat7 hbase-master hbase-regionserver; do echo $i; sysv-rc-conf $i on; done

# enforce Java 7 use for tomcat
sudo perl -pi -e  "s/#JAVA_HOME=\/usr\/lib\/jvm\/openjdk-6-jdk/JAVA_HOME=\/usr\/lib\/jvm\/java-7-oracle-cloudera/;" /etc/default/tomcat7


# configure dirs for seqware
# note these are placed on /mnt since that
# is the ephemeral disk on Amazon instances
mkdir -p /mnt/seqware-oozie
# mount gluster here
# this call will mount the shared gluster disk for clusters or simply fail if not using gluster in single node mode
mount -t glusterfs master:/gv0 /mnt/seqware-oozie
chmod a+rx /mnt
chmod a+rwx /mnt/seqware-oozie
chown -R seqware:seqware /mnt/seqware-oozie
# usr
mkdir -p /usr/tmp/
chmod -R a+rwx /usr/tmp/
ln -s /mnt/seqware-oozie /usr/tmp/seqware-oozie
# datastore
mkdir -p /mnt/datastore
chmod a+rx /mnt
chmod a+rwx /mnt/datastore
ln -s /mnt/datastore /datastore
chown seqware:seqware /mnt/datastore

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
