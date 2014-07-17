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

# Set up memory as a consumable resource
TMPSC=/tmp/sc.tmp
qconf -sc | grep -v 'h_vmem' > $TMPSC
echo "h_vmem              h_vmem     MEMORY      <=    YES         YES        0        0" >> $TMPSC
qconf -Mc $TMPSC
rm $TMPSC

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

qconf -aattr queue slots "[$hostName=`nproc`]" main.q

qconf -mattr queue load_thresholds "np_load_avg=`nproc`" main.q

# Set the amount of memory as the total memory on the system
# unless it is the master node. For master node, amount of memory = 75%
if [ "%{SGE_MASTER_NODE_MEMORY}" == "" ] || [ "$hostName" != "master" ]
then
    qconf -rattr exechost complex_values h_vmem=`free -b |grep Mem | cut -d" " -f5` $hostName
else
    qconf -rattr exechost complex_values h_vmem=%{SGE_MASTER_NODE_MEMORY} $hostName
fi

done
# loop ends here!

# Create profile for "serial" parallel environment
TMPPROFILE=/tmp/serial.profile
echo "pe_name           serial
slots             9999
user_lists        NONE
xuser_lists       NONE
start_proc_args   /bin/true
stop_proc_args    /bin/true
allocation_rule   \$pe_slots
control_slaves    FALSE
job_is_first_task TRUE
urgency_slots     min
accounting_summary FALSE" > $TMPPROFILE
qconf -Ap $TMPPROFILE
qconf -aattr queue pe_list serial main.q
rm $TMPPROFILE

# restart
/etc/init.d/gridengine-exec stop
sleep 4
/etc/init.d/gridengine-master stop
sleep 4
pkill -9 sge_execd
pkill -9 sge_qmaster
sleep 4
/etc/init.d/gridengine-master restart
/etc/init.d/gridengine-exec restart

# change seqware engine to oozie-sge
perl -pi -e 's/SW_DEFAULT_WORKFLOW_ENGINE=oozie/SW_DEFAULT_WORKFLOW_ENGINE=oozie-sge/' /vagrant/settings 
#perl -pi -e 's/OOZIE_SGE_THREADS_PARAM_FORMAT=-pe serial \${threads}/OOZIE_SGE_THREADS_PARAM_FORMAT=/' /vagrant/settings 

# Add sge-init-master startup script
cp /vagrant/sge-init-master /etc/init.d/sge-init
chown root:root /etc/init.d/sge-init
chmod 755 /etc/init.d/sge-init
sysv-rc-conf sge-init on

