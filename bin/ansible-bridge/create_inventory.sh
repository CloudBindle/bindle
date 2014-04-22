# This script is a hack to get me started working with ansible
# I tried wrestling with the ansible provisioner in Vagrant but gave up 

#!/bin/bash
set -o nounset
set -o errexit
 
if [ $# -ne 1 ]; then
    echo "Usage: <working-directory>";
    exit 1;
fi 

working_dir=$1;


function handleType {
	echo "[$1]";
	for d in $2/*/ ; do
            if  [[ $d == *$1* ]]; then
		    if [ -f "$d/Vagrantfile" ]; then
			    cd $d; 
			    vagrant ssh-config > ssh-config.txt ; 
			    # this is ugly, need someone more experienced in bash/sed
                            echo -n `cat ssh-config.txt | sed -n "s/Host\s\([^']\+\)/\1/p" | sed -e 's/^ *//' -e 's/ *$//'` | tr '\n' ' ';
			    echo -n "	ansible_ssh_host=";
			    echo -n `cat ssh-config.txt | sed -n "s/HostName\s\([^']\+\)/\1/p" | sed -e 's/^ *//' -e 's/ *$//'` | tr '\n' ' ';
			    echo -n "	ansible_ssh_user=";
			    echo -n `cat ssh-config.txt | sed -n "s/User\s\([^']\+\)/\1/p" | sed -e 's/^ *//' -e 's/ *$//'` | tr '\n' ' ' ;
			    echo -n "	ansible_ssh_private_key_file=";
			    echo -n `cat ssh-config.txt | sed -n "s/IdentityFile\s\([^']\+\)/\1/p" | sed -e 's/^ *//' -e 's/ *$//'` | tr '\n' ' ';
			    echo ''
			    cd - > /dev/null; 
		    fi
    	    fi
	done
}

handleType master $working_dir
handleType worker $working_dir

echo "[all_groups:children]"
echo "master"
echo "worker"
