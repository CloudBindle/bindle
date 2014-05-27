#!/bin/bash -vx

# common installs for master and workers
yum -y install git xfsprogs
yum -y install hadoop-0.20-mapreduce-jobtracker hadoop-hdfs-datanode hadoop-client hbase-regionserver

# install maven (for CentOS)
wget http://mirrors.gigenet.com/apache/maven/maven-3/3.2.1/binaries/apache-maven-3.2.1-bin.tar.gz
tar -zxvf apache-maven-3.2.1-bin.tar.gz -C /opt/
if [ -f /etc/profile.d/maven.sh ];
then
	echo '#!/bin/bash' > /etc/profile.d/maven.sh
fi
echo 'export M2_HOME=/opt/apache-maven-3.2.1' >> /etc/profile.d/maven.sh
echo 'export M2=$M2_HOME/bin' >> /etc/profile.d/maven.sh
echo 'PATH=$M2:$PATH' >> /etc/profile.d/maven.sh
chmod a+x /etc/profile.d/maven.sh
source /etc/profile.d/maven.sh

usermod -a -G seqware mapred
usermod -a -G mapred seqware

# setup zookeeper
yum -y install zookeeper zookeeper-server
service zookeeper-server init
service zookeeper-server start

# install Hadoop deps, the master node runs the NameNode, SecondaryNameNode and JobTracker
# NOTE: shouldn't really use secondary name node on same box for production
yum -y install hadoop-0.20-mapreduce-jobtracker hadoop-0.20-mapreduce-tasktracker hadoop-hdfs-namenode hadoop-hdfs-secondarynamenode hue hue-server hue-plugins hue-oozie oozie oozie-client hbase hbase-master hbase-thrift


# the repos have been setup in the minimal script
yum -y install httpd

# Install tomcat
cd /tmp
wget http://www.eu.apache.org/dist/tomcat/tomcat-7/v7.0.54/bin/apache-tomcat-7.0.54.tar.gz
tar -xzvf apache-tomcat-7.0.54.tar.gz -C /opt/
cd -
cat > /etc/init.d/tomcat <<\STARTUP_SCRIPT
#!/bin/bash
# description: Tomcat Start Stop Restart
# processname: tomcat
# chkconfig: 234 20 80
JAVA_HOME=/usr/java/jdk1.7.0_45-cloudera
export JAVA_HOME
PATH=$JAVA_HOME/bin:$PATH
export PATH
CATALINA_HOME=/opt/apache-tomcat-7.0.54

case $1 in
	start)
		sh $CATALINA_HOME/bin/startup.sh
		;;
	stop)
		sh $CATALINA_HOME/bin/shutdown.sh
		;;
	restart)
		sh $CATALINA_HOME/bin/shutdown.sh
		sh $CATALINA_HOME/bin/startup.sh
		;;
esac

exit 0
STARTUP_SCRIPT
chmod 755 /etc/init.d/tomcat
chkconfig --add tomcat
chkconfig --level 234 tomcat on
service tomcat start

# install postgresql
sudo sed -i 's/- Base$/- Base\nexclude=postgresql*/' /etc/yum.repos.d/CentOS-Base.repo
sudo sed -i 's/- Updates$/- Updates\nexclude=postgresql*/' /etc/yum.repos.d/CentOS-Base.repo
rpm -Uvh http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-centos93-9.3-1.noarch.rpm
yum -y install postgresql93-server.x86_64
service postgresql-9.3 initdb
sudo sed -i 's/ident$/md5/' /var/lib/pgsql/9.3/data/pg_hba.conf
service postgresql-9.3 start

# setup LZO
#wget -q http://archive.cloudera.com/gplextras/ubuntu/lucid/amd64/gplextras/cloudera.list
#mv cloudera.list /etc/apt/sources.list.d/gplextras.list
#yum update
#yum -y install hadoop-lzo-cdh4

# configuration for hadoop
\cp /vagrant/conf.master.tar.gz /etc/hadoop/
cd /etc/hadoop/
tar zxf conf.master.tar.gz
cd -
/usr/sbin/alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.my_cluster 50
/usr/sbin/alternatives --set hadoop-conf /etc/hadoop/conf.my_cluster

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
\cp desktop/libs/hadoop/java-lib/hue-plugins-*.jar /usr/lib/hadoop-0.20-mapreduce/lib
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
sudo -u postgres psql --command "CREATE DATABASE oozie WITH OWNER = oozie ENCODING = 'UTF-8' TEMPLATE template0 TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "host    oozie         oozie         0.0.0.0/0             md5" >> /var/lib/pgsql/9.3/data/pg_hba.conf
sudo -u postgres /usr/pgsql-9.3/bin/pg_ctl reload -s -D /var/lib/pgsql/9.3/data
perl -pi -e  "s/org.apache.derby.jdbc.EmbeddedDriver/org.postgresql.Driver/;" /etc/oozie/conf.dist/oozie-site.xml
perl -pi -e "s/jdbc:derby:.*create=true/jdbc:postgresql:\/\/localhost:5432\/oozie/;" /etc/oozie/conf.dist/oozie-site.xml
perl -0pi -e "s/<name>oozie.service.JPAService.jdbc.username<\/name>[.\s]*<value>sa<\/value>/<name>oozie.service.JPAService.jdbc.username<\/name><value>oozie<\/value>/;" /etc/oozie/conf.dist/oozie-site.xml
perl -0pi -e "s/<name>oozie.service.JPAService.jdbc.password<\/name>[.\s]*<value> <\/value>/<name>oozie.service.JPAService.jdbc.password<\/name><value>oozie<\/value>/;" /etc/oozie/conf.dist/oozie-site.xml
sudo -u oozie /usr/lib/oozie/bin/ooziedb.sh create -run

service oozie start

# setup hbase
# TODO: need hdfs-site.xml configured properly using alternatives, but for now just copy it
\cp /etc/hadoop/conf/hbase-site.xml /etc/hbase/conf/hbase-site.xml
sudo -u hdfs hadoop fs -mkdir /hbase
sudo -u hdfs hadoop fs -chown hbase /hbase
service hbase-master start
service hbase-regionserver start

service hue restart

# setup daemons to start on boot (tomcat is already set up)
for i in httpd crond hadoop-hdfs-namenode hadoop-hdfs-datanode hadoop-hdfs-secondarynamenode hadoop-0.20-mapreduce-tasktracker hadoop-0.20-mapreduce-jobtracker hue oozie postgresql hbase-master hbase-regionserver; do echo $i; chkconfig $i on; done

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
# see http://www.howtoforge.com/setting-up-an-nfs-server-and-client-on-centos-6.3
yum -y install rpcbind nfs-utils nfs-utils-lib
service rpcbind start
service nfslock start
service nfs start
echo '%{EXPORTS}' >> /etc/exports
exportfs -ra
# TODO: get rid of portmap localhost setting maybe... don't see the file they refer to
service rpcbind restart
service nfs restart
chkconfig --level 235 nfs on
chkconfig --level 235 nfslock on
chkconfig --level 235 rpcbind on

# Add hadoop-init startup script
# TODO: I had to comment this out previously... might need to do so again. --LC
#\cp /vagrant/hadoop-init-master /etc/init.d/hadoop-init
#chown root:root /etc/init.d/hadoop-init
#chmod 755 /etc/init.d/hadoop-init
#chkconfig --level 235 hadoop-init on
