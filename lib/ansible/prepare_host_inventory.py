import argparse
from os import path as path
parser = argparse.ArgumentParser(description="Update ansible host inventory with IPs of hosts parsed from vagrant target directories")
parser.add_argument("inventory_file_path", help="Full path to ansible inventory file to be created/updated")
parser.add_argument("cluster_parent_folder_path", help="Path to the parent folder that will be searched for the presence of vagrant clusters")
args = parser.parse_args()
arg_dict = vars(args)
inventory_file_path = arg_dict["inventory_file_path"]
cluster_parent_folder_path = arg_dict["cluster_parent_folder_path"]

def visit_dir(arg,dirname,names):
	print dirname

if not path.exists(cluster_parent_folder_path):
	print "Cluster path does not exist"

path.walk(cluster_parent_folder_path, visit_dir,None)



