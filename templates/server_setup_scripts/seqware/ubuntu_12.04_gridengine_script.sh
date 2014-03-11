#!/bin/bash

# see http://helms-deep.cable.nu/~rwh/blog/?p=159
# you would test this by (as seqware) doing:
# "echo hostname | qsub -cwd
# watch qstat -f"
# you should then see your job run and also see STDIN.* files get created with the hostname in them

# get packages
apt-get update
export DEBIAN_FRONTEND=noninteractive
apt-get -q -y --force-yes install gridengine-client gridengine-common gridengine-exec gridengine-master

# restart
/etc/init.d/gridengine-exec stop
/etc/init.d/gridengine-master restart
/etc/init.d/gridengine-exec start

# configure
#export HOST=`hostname`
hostname master
export HOST=master
sudo -u sgeadmin qconf -am seqware
qconf -au seqware users
qconf -as $HOST

# this is interactive... how do I load from a file?
for hostName in %{SGE_HOSTS}; do

#tried to indent the following nicely, but the EOF seemed to kill that idea
cat >/tmp/qconf-editor.sh <<EOF
#!/bin/sh
sleep 1
perl -pi -e 's/^hostname.*$/hostname $hostName/' \$1
EOF
chmod +x /tmp/qconf-editor.sh
export EDITOR=/tmp/qconf-editor.sh
qconf -ae

# now do this again
cat >/tmp/qconf-editor.sh <<EOF
#!/bin/sh
sleep 1
perl -pi -e 's/^hostlist.*$/hostlist %{SGE_HOSTS}/' \$1
EOF
chmod +x /tmp/qconf-editor.sh
export EDITOR=/tmp/qconf-editor.sh
qconf -ahgrp @allhosts
# might need to do this instead
qconf -mhgrp @allhosts


# config
qconf -aattr hostgroup hostlist %{SGE_HOSTS} @allhosts

# interactive
# uses the same editor as above
qconf -aq main.q
# same as above, may need to modify the queue instead
qconf -mq main.q

qconf -aattr queue hostlist @allhosts main.q

qconf -aattr queue slots "[$hostName=1]" main.q

done
# loop ends here!

# restart
/etc/init.d/gridengine-exec stop
/etc/init.d/gridengine-master restart
/etc/init.d/gridengine-exec start

# change seqware engine to oozie-sge
perl -pi -e 's/SW_DEFAULT_WORKFLOW_ENGINE=oozie/SW_DEFAULT_WORKFLOW_ENGINE=oozie-sge/' /vagrant/settings 
perl -pi -e 's/OOZIE_SGE_THREADS_PARAM_FORMAT=-pe serial \${threads}/OOZIE_SGE_THREADS_PARAM_FORMAT=/' /vagrant/settings 

# Add sge-init-master startup script
cp /vagrant/sge-init-master /etc/init.d/sge-init
chown root:root /etc/init.d/sge-init
chmod 755 /etc/init.d/sge-init
sysv-rc-conf sge-init on

