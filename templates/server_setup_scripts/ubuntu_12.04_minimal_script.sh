#!/bin/bash -vx

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

# setup ephemeral and EBS volumes that are attached to this system
apt-get update
apt-get -q -y --force-yes install ecryptfs-utils xfsprogs
perl /vagrant/setup_volumes.pl --output /vagrant/volumes_report.txt %{GLUSTER_DEVICE_WHITELIST} %{GLUSTER_DIRECTORY_PATH}

# now setup volumes for use with gluster
# the default version of gluster (3.2?) appears to suffer from the problem described here: https://bugzilla.redhat.com/show_bug.cgi?id=807976
# version 3.4 appears to suffer from the problem described here: https://bugzilla.redhat.com/show_bug.cgi?id=977497
# see Gluster's site for more info, this is the official way to install 3.5: http://download.gluster.org/pub/gluster/glusterfs/3.5/3.5.0/Ubuntu/Ubuntu.README
add-apt-repository -y ppa:semiosis/ubuntu-glusterfs-3.5
apt-get update
apt-get -q -y --force-yes install glusterfs-server
perl /vagrant/setup_gluster_volumes.pl --dir-map /vagrant/volumes_report.txt --output /vagrant/gluster_volumes_report.txt 
