use strict;
use warnings;

use Getopt::Long;

# PURPOSE:
# This script attempts to format, mount, and encrypt all the volumes available . You
# will be left with various devices mounted as /mnt/<devname>/ with a directory
# called /mnt/<devname>/encrypted under which anything written will be
# encrypted using ecryptfs with a random key. Anything outside of this
# directory will not be encrypted. If ecryptfs is not installed the encrypted
# directory is not created.
# ASSUMPTIONS:
# * this script does not setup HDFS or Gluster
# * you have ecryptfs and mkfs.xfs installed
# TODO

my $out_file = "mount_report.txt";
my $whitelist;
my $gluster_directory_list;
my @wlist;
my @dir_list;

GetOptions (
  "output=s" => \$out_file,
  "whitelist=s" => \$whitelist,
  "directorypath=s" => \$gluster_directory_list,
);

if (defined $whitelist){
  @wlist = read_list($whitelist);
}
else{
  @wlist = ();
}
if (defined $gluster_directory_list){
  @dir_list = read_list($gluster_directory_list);
  make_directories(@dir_list);
}
else{
  @dir_list = ();
}

my $mounted_device = 0;

my $final_list;
my $list = `ls -1 /dev/sd* /dev/xv*`;
my @list = split /\n/, $list;

foreach my $dev (@list) {
  # skip if doesn't exist
  next if (!-e $dev || -l $dev);

  print "All Devices: $dev\n";
  # true if empty or it's on the whitelist

  next if ( not whitelist($dev, @wlist));
  # then extra device so can continue
  print "DEV: $dev\n";

  # if already mounted just add directory
  if( not mounted($dev) ) {
      print " NOT MOUNTED!\n";
      my $format = system("bash -c 'mkfs.xfs -i size=512 $dev &> /dev/null'");
      if ($format != 0 ) { 
         print "ERROR: UNABLE TO FORMAT: $dev\n";
      } 
      else { 
          print " FORMATTED OK!\n"; 
          $dev =~ /\/dev\/(\S+)/;

          my $dev_name = $1;
          print " MOUNTING: $dev_name\n";
          my $mount = system("bash -c 'mkdir -p /$dev_name && mount $dev /$dev_name' && chmod a+rwx /$dev_name");

          if ($mount == 0) {
              $mounted_device = 1;
          }
          else {
              print " UNABLE TO MOUNT $dev on /$dev_name\n";
          }
      }
  } 
  else {
    print " NOT MOUNTING SINCE ALREADY MOUNTED!\n";
    $mounted_device = 1;
  }

  my $mount_path = find_mount_path($dev);

  # if ecryptfs was success, the mount path gets encrypted added to it
  $mount_path = "$mount_path/encrypted" if ( setup_ecryptfs($mount_path) );

  # add to the list of mounted dirs
  $final_list .= "$mount_path\n";
}

# now handle the list of dirs
# for each dir in list
# do setup_ecrypt
# add to final_list
if (not $mounted_device){
  foreach my $dir (@dir_list) {
    my $mount_path = $dir;
    if (setup_ecryptfs($mount_path)) {
      $mount_path = "$mount_path/encrypted";
    }
    $final_list .= "$mount_path\n";
  }
}

$final_list //= "";

# OUTPUT REPORT

open my $out, '>', $out_file or die "Can't open output file: $out_file\n";
print $out $final_list;
close $out;


# SUBROUTINES

# separates the string into an array 
sub read_list {
  my ($data) = @_;

  my @list = split /,/, $data;

  return @list;
}

# makes the directories cased on the list
sub make_directories {
  my (@directories) = @_;
  foreach my $dir (@directories){
    system("mkdir -p $dir");
  }
}

# determines if the device is permitted to be used as a volume
sub whitelist {
  my ($dev, @whlist) = @_;

  foreach (@whlist) {
    print "DEV $dev\n";
    my ($option1,$option2,$option3) = ("/dev/sd$_", "/dev/hd$_","/dev/xvd$_");
    print "option1 $option1\n";
    if ($dev =~ m/^$option1|$option2|$option3$/i){
      print " WHITELIST DEV $dev\n";
      return 1;
    }
  }
  
  return 0;
}

sub mounted {
  my $dev = shift;

  # blacklist any drives that are likely to be root partition
  if ($dev =~ /sda|hda|xvda/) {
    print " DEV BLACKLISTED: $dev\n";
    return 1;
  }

  my $count = `df -h | grep $dev | wc -l`;
  chomp $count;

  return $count;
}

sub setup_ecryptfs {
  my ($dir) = @_;

  my $ecrypt_result;
  # attempt to find this tool
  if ( system("which mount.ecryptfs") == 0) {
    my $found = `mount | grep $dir/encrypted | grep 'type ecryptfs' | wc -l`;
    chomp $found;
    if ($found =~ /0/) {
      my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9 );
      my $password = join("", @chars[ map { rand @chars } ( 1 .. 11 ) ]);
      my $ecrypt_cmd = "mkdir -p $dir/encrypted && mount.ecryptfs $dir/encrypted $dir/encrypted -o ecryptfs_cipher=aes,ecryptfs_key_bytes=16,ecryptfs_passthrough=n,ecryptfs_enable_filename_crypto=n,no_sig_cache,key=passphrase:passwd=$password && chmod a+rwx $dir/encrypted";
      $ecrypt_result = system($ecrypt_cmd);
      if ($ecrypt_result) {
         print " ERROR: there was a problem running the ecrypt command $ecrypt_cmd\n";
         return 0;
      }
    } 
    else {
      print " ALREADY ENCRYPTED: this was already encrypted $dir so skipping.\n";
    }
  } 
  else {
    print " ERROR: can't find mount.ecryptfs so skipping encryption of the HDFS volume\n";
    return 0;
  }
  return 1;
}

sub find_mount_path {
  my ($dev) = @_;

  my $path = `df -h | grep $dev | awk '{ print \$6}'`;
  chomp $path;

  return $path;
}
