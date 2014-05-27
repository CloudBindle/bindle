#!/bin/bash

# see http://helms-deep.cable.nu/~rwh/blog/?p=159
# you would test this by (as seqware) doing:
# "echo hostname | qsub -cwd
# watch qstat -f"
# you should then see your job run and also see STDIN.* files get created with the hostname in them

# get packages
yum -y install gridengine-execd gridengine-qmaster gridengine

# make dirs
mkdir -p /var/spool/gridengine/default/qmaster
chown sgeadmin:sgeadmin /var/spool/gridengine/default/qmaster
rm -rf /var/spool/gridengine/default/spooldb
rm -rf /usr/share/gridengine/default

# set env
export SGE_ROOT=/usr/share/gridengine

# now setup via the stupid installation process
cd /usr/share/gridengine
echo 'SGE_ROOT="/usr/share/gridengine"
SGE_QMASTER_PORT=6444
SGE_EXECD_PORT=6445
SGE_ENABLE_SMF="false"
SGE_ENABLE_ST="true"
SGE_CLUSTER_NAME="p6444"
SGE_JMX_PORT="Please enter port"
SGE_JMX_SSL="false"
SGE_JMX_SSL_CLIENT="false"
SGE_JMX_SSL_KEYSTORE="Please enter absolute path of server keystore file"
SGE_JMX_SSL_KEYSTORE_PW="Please enter the server keystore password"
SGE_JVM_LIB_PATH="none"
SGE_ADDITIONAL_JVM_ARGS="-Xmx256m"
CELL_NAME="default"
ADMIN_USER=""
QMASTER_SPOOL_DIR="/var/spool/gridengine/default/qmaster"
EXECD_SPOOL_DIR="/var/spool/gridengine"
GID_RANGE="16000-16100"
SPOOLING_METHOD="berkeleydb"
DB_SPOOLING_SERVER="none"
DB_SPOOLING_DIR="/var/spool/gridengine/default/spooldb"
PAR_EXECD_INST_COUNT="20"
ADMIN_HOST_LIST="master"
SUBMIT_HOST_LIST="master"
EXEC_HOST_LIST="master"
EXECD_SPOOL_DIR_LOCAL="/var/spool/gridengine"
HOSTNAME_RESOLVING="true"
SHELL_NAME="ssh"
COPY_COMMAND="scp"
DEFAULT_DOMAIN="none"
ADMIN_MAIL="none"
ADD_TO_RC="false"
SET_FILE_PERMS="false"
RESCHEDULE_JOBS="wait"
SCHEDD_CONF="1"
SHADOW_HOST=""
EXEC_HOST_LIST_RM=""
REMOVE_RC="false"
WINDOWS_SUPPORT="false"
WIN_ADMIN_NAME="Administrator"
WIN_DOMAIN_ACCESS="false"
CSP_RECREATE="true"
CSP_COPY_CERTS="false"
CSP_COUNTRY_CODE="DE"
CSP_STATE="Germany"
CSP_LOCATION="Building"
CSP_ORGA="Organisation"
CSP_ORGA_UNIT="Organisation_unit"
CSP_MAIL_ADDRESS="name@yourdomain.com"' > /tmp/sge.config
/usr/share/gridengine/inst_sge -m -x -auto /tmp/sge.config
cd -

# restart
/etc/init.d/sge_execd stop
sleep 4
/etc/init.d/sgemaster stop
sleep 4
pkill -9 sge_execd
pkill -9 sge_qmaster
sleep 4
/etc/init.d/sgemaster restart
/etc/init.d/sge_execd restart

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
rm -f $TMPSC

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
qconf -aq all.q
# same as above, may need to modify the queue instead
qconf -mq all.q

qconf -aattr queue hostlist @allhosts all.q

qconf -aattr queue slots "[$hostName=`nproc`]" all.q

qconf -mattr queue load_thresholds "np_load_avg=`nproc`" all.q

# Set the amount of memory as the total memory on the system
qconf -rattr exechost complex_values h_vmem=`free -b |grep Mem | cut -d" " -f5` $hostName

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
qconf -aattr queue pe_list serial all.q
rm -f $TMPPROFILE

# restart
/etc/init.d/sge_execd stop
sleep 4
/etc/init.d/sgemaster stop
sleep 4
pkill -9 sge_execd
pkill -9 sge_qmaster
sleep 4
/etc/init.d/sgemaster restart
/etc/init.d/sge_execd restart

# change seqware engine to oozie-sge
perl -pi -e 's/SW_DEFAULT_WORKFLOW_ENGINE=oozie/SW_DEFAULT_WORKFLOW_ENGINE=oozie-sge/' /vagrant/settings
#perl -pi -e 's/OOZIE_SGE_THREADS_PARAM_FORMAT=-pe serial \${threads}/OOZIE_SGE_THREADS_PARAM_FORMAT=/' /vagrant/settings

# Add sge-init-master startup script
#\cp /vagrant/sge-init-master /etc/init.d/sge-init
#chown root:root /etc/init.d/sge-init
#chmod 755 /etc/init.d/sge-init
#chkconfig --levels 235 sge-init on
