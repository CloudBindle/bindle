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
