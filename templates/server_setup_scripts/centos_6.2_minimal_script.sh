#!/bin/bash -vx

#yum update
yum install curl unzip -y

# add seqware user
useradd -d /home/seqware -m seqware -s /bin/bash

# ensure locale is set to en-US (and remains so)
sudo sed "s/^AcceptEnv/#AcceptEnv/" -i /etc/ssh/sshd_config
#sudo locale-gen en_US.UTF-8
#sudo dpkg-reconfigure locales
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
echo "export LANGUAGE=en_US.UTF-8" >> /etc/bash.bashrc
echo "export LANG=en_US.UTF-8" >> /etc/bash.bashrc
echo "export LC_ALL=en_US.UTF-8" >> /etc/bash.bashrc
echo "export LC_CTYPE=en_US.UTF-8" >> /etc/bash.bashrc
echo 'LANG="en_US.UTF-8"' | sudo tee /etc/default/locale
echo 'LC_ALL="en_US.UTF-8"' | sudo tee -a /etc/default/locale
echo 'LC_CTYPE="en_US.UTF-8"' | sudo tee -a /etc/default/locale
echo 'LANG="en_US.UTF-8"' | sudo tee -a /etc/environment
echo 'LC_ALL="en_US.UTF-8"' | sudo tee -a /etc/environment
echo 'LC_CTYPE="en_US.UTF-8"' | sudo tee -a /etc/environment

# install the hadoop repo
wget -q -O /etc/yum.repos.d/cloudera-cdh4.repo http://archive.cloudera.com/cdh4/redhat/6/i386/cdh/cloudera-cdh4.repo &> /dev/null
sudo rpm --import http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera

# get packages
#yum update
#yum -q -y --force-yes install oracle-j2sdk1.6 cloudera-manager-server-db cloudera-manager-server cloudera-manager-daemons
#yum -q -y --force-yes install oracle-j2sdk1.6 hadoop-0.20-conf-pseudo hue hue-server hue-plugins oozie oozie-client postgresql-9.1 postgresql-client-9.1 tomcat6-common tomcat6 apache2 git maven sysv-rc-conf hbase-master xfsprogs

# get Java
cd /usr/local/src
rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt
wget http://packages.sw.be/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm
rpm -Uhv rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm

yum -y install java-1.6.0-openjdk.x86_64 -y
export JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk-1.6.0.0.x86_64/jre
