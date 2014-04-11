# a place for PanCancer specific config related to ephemeral disks on AWS

# general apt-get
apt-get update
export DEBIAN_FRONTEND=noninteractive

# general items needed for bwa workflow
apt-get -q -y --force-yes install ecryptfs-utils

# now call the perl code to find ephemeral disks and mount them
perl /vagrant/setup_hdfs_volumes.pl

