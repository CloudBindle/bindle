import argparse
from os import path as path
import re
from sets import Set
from subprocess import check_output, Popen, PIPE

parser = argparse.ArgumentParser(description="Update ansible host inventory with IPs of hosts parsed from vagrant target directories")
parser.add_argument("inventory_file_path", help="Full path to ansible inventory file to be created/updated")
parser.add_argument("cluster_parent_folder_path", help="Path to the parent folder that will be searched for the presence of vagrant clusters")
args = parser.parse_args()
arg_dict = vars(args)
inventory_file_path = arg_dict["inventory_file_path"]
cluster_parent_folder_path = arg_dict["cluster_parent_folder_path"]
node_paths =  Set()
cluster_dict = {}
all_masters_list = []
def visit_dir(arg,dirname,names):
	my_match = re.search(".*target-(?P<cluster_name>.*?)/(?P<node_name>master|worker[0-9]+)(?<!\.vagrant)", dirname)
	if my_match:
		node_paths.add((my_match.group("cluster_name"), my_match.group("node_name"), my_match.group(0)))	

if not path.exists(cluster_parent_folder_path):
	print "Cluster path does not exist"

path.walk(cluster_parent_folder_path, visit_dir,None)

for (cluster_name, node_name, my_path) in node_paths:
	return_val = ""
	(prog_out, prog_err) = Popen(["vagrant", "ssh-config"],stdin=PIPE, stdout=PIPE, stderr=PIPE, cwd=my_path).communicate()	
	my_match = re.search("HostName (?P<host_ip>[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3})\n", prog_out)
	if my_match:
		cluster_dict.setdefault(cluster_name, []).append((node_name, my_match.group("host_ip")))
		print "Discovered host: Cluster name - {}, Host name - {}, Host IP - {}\n".format(cluster_name, node_name, my_match.group("host_ip"))	
		if node_name == "master":
			all_masters_list.append((cluster_name, node_name, my_match.group("host_ip")))

outfile = open(inventory_file_path, "w")

for cluster_name in cluster_dict:
	outfile.write("[" + cluster_name + "]\n");
	for (node_name, node_ip) in cluster_dict[cluster_name]:
		outfile.write(node_name + " ansible_ssh_host=" + node_ip + "\n")

outfile.write("[all-masters]\n")
for (cluster_name, node_name, node_ip) in all_masters_list:
	outfile.write(cluster_name + "-" + node_name + " ansible_ssh_host=" + node_ip + "\n")
