#!/bin/bash -vx

# disable SELinux
echo 0 > /selinux/enforce

# ensure updates repository is available, and heartbleed vulnerability is fixed
sudo sed -i '1!N; s/\[updates\]\nenabled\s=\s0/[updates]\nenabled = 1/' /etc/yum.repos.d/CentOS-Base.repo
yum install -y openssl openssh
sudo service httpd restart
sudo service nginx restart
sudo service sshd restart

# install Gluster dependencies
sudo yum install -y http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
sudo yum install -y --enablerepo=epel dbench git mock nfs-utils perl-Test-Harness xfsprogs libacl-devel
sudo yum install -y --enablerepo=epel python-webob1.0 python-paste-deploy1.5 python-sphinx10 redhat-rpm-config
sudo yum install -y --enablerepo=epel autoconf automake bison dos2unix flex fuse-devel libaio-devel libibverbs-devel \
     librdmacm-devel libtool libxml2-devel lvm2-devel make openssl-devel pkgconfig \
     python-devel python-eventlet python-netifaces python-paste-deploy \
     python-simplejson python-sphinx python-webob pyxattr readline-devel rpm-build \
     systemtap-sdt-devel tar ecryptfs-utils

# mock user (for Gluster)
sudo useradd -g mock mock

# yum update
yum install -y curl unzip attr

# ulimit
echo "fs.file-max = 1623050" >> /etc/sysctl.conf
echo "*                soft    nofile          162305" >> /etc/security/limits.conf
echo "*                hard    nofile          162305" >> /etc/security/limits.conf

# add seqware user
mkdir -p /mnt/home
useradd -d /mnt/home/seqware -m seqware -s /bin/bash
ln -s ~seqware /home/seqware

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
wget -q -O /etc/yum.repos.d/cloudera-cdh4.repo http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh/cloudera-cdh4.repo &> /dev/null
sudo rpm --import http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera

# get packages
#yum update
#yum -y install oracle-j2sdk1.6 cloudera-manager-server-db cloudera-manager-server cloudera-manager-daemons
#yum -y install oracle-j2sdk1.6 hadoop-0.20-conf-pseudo hue hue-server hue-plugins oozie oozie-client postgresql-9.1 postgresql-client-9.1 tomcat7-common tomcat7 apache2 git maven hbase-master xfsprogs

# get Java 1.7
cd /tmp
wget http://download.oracle.com/otn-pub/java/jdk/7u55-b13/jdk-7u55-linux-x64.rpm
rpm -Uvh /tmp/jdk-7u55-linux-x64.rpm
alternatives --install /usr/bin/java java /usr/java/latest/jre/bin/java 200000
alternatives --install /usr/bin/javaws javaws /usr/java/latest/jre/bin/javaws 200000
alternatives --install /usr/lib/mozilla/plugins/libjavaplugin.so libjavaplugin.so /usr/java/latest/jre/lib/i386/libnpjp2.so 200000
alternatives --install /usr/lib64/mozilla/plugins/libjavaplugin.so libjavaplugin.so.x86_64 /usr/java/latest/jre/lib/amd64/libnpjp2.so 200000
alternatives --install /usr/bin/javac javac /usr/java/latest/bin/javac 200000
alternatives --install /usr/bin/jar jar /usr/java/latest/bin/jar 200000
if [ -f /etc/profile.d/java-dev.sh ];
then
	echo '#!/bin/bash' > /etc/profile.d/java-dev.sh
fi
echo 'export JAVA_HOME=/usr/java/latest' >> /etc/profile.d/java-dev.sh
echo 'PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile.d/java-dev.sh
chmod a+x /etc/profile.d/java-dev.sh
source /etc/profile.d/java-dev.sh

# get Java 1.6
#cd /usr/local/src
#rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt
#wget http://packages.sw.be/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm
#rpm -Uhv rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm
#
#yum -y install java-1.6.0-openjdk.x86_64 -y
#export JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk-1.6.0.0.x86_64/jre
#yum -y install java-1.6.0-openjdk-devel

# if we have a local maven mirror defined, set it up
if [ -n "%{MAVEN_MIRROR}" ]; then
	mkdir ~seqware/.m2
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><settings xmlns=\"http://maven.apache.org/SETTINGS/1.0.0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd\"> <mirrors> <mirror> <id>artifactory</id><mirrorOf>*</mirrorOf> <url> %{MAVEN_MIRROR} </url>            <name>Artifactory</name>        </mirror>    </mirrors></settings>" > ~seqware/.m2/settings.xml
fi

# setup ephemeral and EBS volumes that are attached to this system
# (ecryptfs-utils and xfsprogs are already installed above)
perl /vagrant/setup_volumes.pl --output /vagrant/volumes_report.txt %{GLUSTER_DEVICE_BLACKLIST} %{GLUSTER_DEVICE_WHITELIST}

# now setup volumes for use with gluster
# the default version of gluster (3.2?) appears to suffer from the problem described here: https://bugzilla.redhat.com/show_bug.cgi?id=807976
# see Gluster's site for more info, this is the official way to install 3.4: http://download.gluster.org/pub/gluster/glusterfs/3.4/3.4.3/Ubuntu/Ubuntu.README
wget -q -O /etc/yum.repos.d/glusterfs-epel.repo http://download.gluster.org/pub/gluster/glusterfs/3.5/3.5.0/EPEL.repo/glusterfs-epel.repo &> /dev/null
rpm --import http://download.gluster.org/pub/gluster/glusterfs/3.5/3.5.0/EPEL.repo/pub.key
yum install -y glusterfs-server-3.5.0-2.el6
perl /vagrant/setup_gluster_volumes.pl --dir-map /vagrant/volumes_report.txt --output /vagrant/gluster_volumes_report.txt