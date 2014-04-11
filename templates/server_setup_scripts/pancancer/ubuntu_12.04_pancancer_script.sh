# a place for PanCancer specific config

# general apt-get
apt-get update
export DEBIAN_FRONTEND=noninteractive

# general items needed for bwa workflow
apt-get -q -y --force-yes install liblz-dev zlib1g-dev libxml-dom-perl samtools libossp-uuid-perl libjson-perl libxml-libxml-perl

# download public key
if [ ! -e "cghub_public.key" ]; then
  wget https://cghub.ucsc.edu/software/downloads/cghub_public.key
fi

# install the docker daemon
# This is a problem, docker notes that it works best on a 3.8 kernel, Ubuntu 12 is using the 3.2 kernel but this requires a reboot to work properly
# The alternative is an update to the ubuntu version, this requires discussion

# link the docker directory to /mnt, this is going to potentially use a lot of space
sudo mkdir -p /mnt/docker
sudo ln -s /mnt/docker/ /var/lib/docker

# install docker daemon
sudo apt-get  -q -y --force-yes install apt-transport-https
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
sudo sh -c "echo deb https://get.docker.io/ubuntu docker main\
> /etc/apt/sources.list.d/docker.list"
sudo apt-get update
sudo apt-get  -q -y --force-yes install lxc-docker

# give non-root user access to docker
sudo groupadd docker
sudo gpasswd -a seqware docker
sudo service docker restart


# dependencies for genetorrent, these packages crash on 13.10 
apt-get -q -y --force-yes install libboost-filesystem1.48.0 libboost-program-options1.48.0 libboost-regex1.48.0 libboost-system1.48.0 libicu48 libxerces-c3.1 libxqilla6
cd /tmp
wget http://cghub.ucsc.edu/software/downloads/GeneTorrent/3.8.5/genetorrent-common_3.8.5-ubuntu2.91-12.04_amd64.deb
wget http://cghub.ucsc.edu/software/downloads/GeneTorrent/3.8.5/genetorrent-download_3.8.5-ubuntu2.91-12.04_amd64.deb
wget http://cghub.ucsc.edu/software/downloads/GeneTorrent/3.8.5/genetorrent-upload_3.8.5-ubuntu2.91-12.04_amd64.deb
# finally install these
dpkg -i genetorrent-common_3.8.5-ubuntu2.91-12.04_amd64.deb genetorrent-download_3.8.5-ubuntu2.91-12.04_amd64.deb genetorrent-upload_3.8.5-ubuntu2.91-12.04_amd64.deb
cd -
