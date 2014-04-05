#!/bin/bash -vx

# workaround for Korea's cloud
if [ -d "/maha" ]; then
  umount  /maha
  perl -p -i -e 's/uid=1000,gid=1000/defaults/' /etc/fstab
  mount /maha
  mount -o rw,bind `mount | grep maha\/tmp | awk '{print $1}'` /mnt
fi

# workaround for Tokyo's cloud
if [ -d "/nshare4" ]; then 
  dir=/nshare4/vmtmp/$RANDOM 
  mkdir -p $dir 
  mount -o rw,bind $dir /mnt 
fi

# workaround for Bionimbus' PDC cloud
if [ -d "/glusterfs" ]; then
  # this is causing problems with the server not being in the whitelist
  rm /etc/apt/sources.list.d/R.list
  # this is required to get the proxy settings in each subsequent, non-interactive shell
  echo "source /etc/profile.d/proxy.sh" > ~/.bashrc.new
  cat ~/.bashrc >> ~/.bashrc.new
  mv ~/.bashrc.new ~/.bashrc
  # now filesystem
  mkdir -p /glusterfs/users/BOCONNOR/seqware-oozie
  chmod a+rwx /glusterfs/users/BOCONNOR/seqware-oozie
  mkdir -p /mnt/seqware-oozie
  mount -o bind /glusterfs/users/BOCONNOR/seqware-oozie /mnt/seqware-oozie
fi

# basic tools
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install curl unzip -y

# add seqware user
mkdir -p /mnt/home
useradd -d /mnt/home/seqware -m seqware -s /bin/bash
ln -s ~seqware /home/seqware

# ensure locale is set to en-US (and remains so)
sudo sed "s/^AcceptEnv/#AcceptEnv/" -i /etc/ssh/sshd_config
sudo locale-gen en_US.UTF-8
sudo dpkg-reconfigure locales
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
#wget -q http://archive.cloudera.com/cdh4/one-click-install/precise/amd64/cdh4-repository_1.0_all.deb &> /dev/null
#dpkg -i cdh4-repository_1.0_all.deb &> /dev/null
echo "deb [arch=amd64] http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh precise-cdh4.5.0 contrib" | sudo tee -a /etc/apt/sources.list.d/cloudera.list
echo "deb-src http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh precise-cdh4.5.0 contrib" | sudo tee -a /etc/apt/sources.list.d/cloudera.list
curl -s http://archive.cloudera.com/cdh4/ubuntu/precise/amd64/cdh/archive.key | sudo apt-key add -


# setup cloudera manager repo (not used)
#REPOCM=${REPOCM:-cm4}
#CM_REPO_HOST=${CM_REPO_HOST:-archive.cloudera.com}
#CM_MAJOR_VERSION=$(echo $REPOCM | sed -e 's/cm\\([0-9]\\).*/\\1/')
#CM_VERSION=$(echo $REPOCM | sed -e 's/cm\\([0-9][0-9]*\\)/\\1/')
#OS_CODENAME=$(lsb_release -sc)
#OS_DISTID=$(lsb_release -si | tr '[A-Z]' '[a-z]')
#if [ $CM_MAJOR_VERSION -ge 4 ]; then
#  cat > /etc/apt/sources.list.d/cloudera-$REPOCM.list <<EOF
#deb [arch=amd64] http://$CM_REPO_HOST/cm$CM_MAJOR_VERSION/$OS_DISTID/$OS_CODENAME/amd64/cm $OS_CODENAME-$REPOCM contrib
#deb-src http://$CM_REPO_HOST/cm$CM_MAJOR_VERSION/$OS_DISTID/$OS_CODENAME/amd64/cm $OS_CODENAME-$REPOCM contrib
#EOF
#curl -s http://$CM_REPO_HOST/cm$CM_MAJOR_VERSION/$OS_DISTID/$OS_CODENAME/amd64/cm/archive.key > key
#apt-key add key
#rm key
#fi

# get packages
apt-get update
#apt-get -q -y --force-yes install oracle-j2sdk1.6 cloudera-manager-server-db cloudera-manager-server cloudera-manager-daemons
#apt-get -q -y --force-yes install oracle-j2sdk1.6 hadoop-0.20-conf-pseudo hue hue-server hue-plugins oozie oozie-client postgresql-9.1 postgresql-client-9.1 tomcat7-common tomcat7 apache2 git maven sysv-rc-conf hbase-master xfsprogs
# get Java
apt-get -q -y --force-yes install libasound2 libxi6 libxtst6 libxt6 language-pack-en 
cd /tmp
wget http://archive.cloudera.com/cm5/ubuntu/lucid/amd64/cm/pool/contrib/o/oracle-j2sdk1.7/oracle-j2sdk1.7_1.7.0+update25-1_amd64.deb 
dpkg -i oracle-j2sdk1.7_1.7.0+update25-1_amd64.deb
cd -

# cloudera 1.7 java package doesn't set up alternatives for some reason
update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-7-oracle-cloudera/jre/bin/java 2000
update-alternatives --set java /usr/lib/jvm/java-7-oracle-cloudera/jre/bin/java
echo 'JAVA_HOME=/usr/lib/jvm/java-7-oracle-cloudera' | sudo tee -a /etc/environment

# if we have a local maven mirror defined, set it up
if [ -n "%{MAVEN_MIRROR}" ]; then 
	mkdir ~seqware/.m2
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><settings xmlns=\"http://maven.apache.org/SETTINGS/1.0.0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd\"> <mirrors> <mirror> <id>artifactory</id><mirrorOf>*</mirrorOf> <url> %{MAVEN_MIRROR} </url>            <name>Artifactory</name>        </mirror>    </mirrors></settings>" > ~seqware/.m2/settings.xml
fi
