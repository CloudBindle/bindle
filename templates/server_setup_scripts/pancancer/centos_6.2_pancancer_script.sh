# a place for PanCancer specific config

# general items needed for bwa workflow
yum install -y zlib-devel perl-XML-LibXML samtools uuid-perl perl-JSON perl-XML-LibXML perl-Try-Tiny gd-devel gcc-c++ autoconf automake ncurses-devel pkgconfig

# download public key
if [ ! -e "cghub_public.key" ]; then
  wget https://cghub.ucsc.edu/software/downloads/cghub_public.key
fi

# dependencies for genetorrent
yum install -y boost-devel boost-filesystem boost-program-options boost-regex boost-system libicu xerces-c-devel xqilla-devel
cd /tmp
wget http://cghub.ucsc.edu/software/downloads/GeneTorrent/3.8.5/genetorrent-common_3.8.5-11.91.el6.x86_64.rpm
wget http://cghub.ucsc.edu/software/downloads/GeneTorrent/3.8.5/genetorrent-download_3.8.5-11.91.el6.x86_64.rpm
wget http://cghub.ucsc.edu/software/downloads/GeneTorrent/3.8.5/genetorrent-upload_3.8.5-11.91.el6.x86_64.rpm
# finally install these
rpm -Uhv genetorrent-common_3.8.5-11.91.el6.x86_64.rpm
rpm -Uhv genetorrent-download_3.8.5-11.91.el6.x86_64.rpm
rpm -Uhv genetorrent-upload_3.8.5-11.91.el6.x86_64.rpm
cd -
