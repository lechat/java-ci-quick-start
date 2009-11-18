#!/bin/bash
techo () 
{
    echo "`date +"%y-%m-%d %H:%M:%S"` - $1" | tee -a logs/${dttime}/setup_qs.log
}

dttime=`date +"%y%m%d_%H%M%S"`
startdir=`pwd`
mkdir -p logs/${dttime}/
techo "Started at `date`"
if [ "$(whoami)" != "root" ]; then
    echo "Sorry, you need to run this script as root. Use: sudo ./vmware_tools.sh"
    exit 1
fi

techo "Checking if HTTP and HTTPS working properly"
wget -U "ZX_Spectrum/1997 (Sinclair_BASIC)" http://www.google.com/
if [ "$?" != "0" ]; then
    echo "HTTP protocol failed. Please configure 'http_proxy' environment variable:" | tee -a logs/${dttime}/setup_qs.log
    echo "" | tee -a logs/${dttime}/setup_qs.log
    echo "export http_proxy=proxy.server:port" | tee -a logs/${dttime}/setup_qs.log
    cd ..
    exit 2
fi
rm index.html

wget -U "ZX_Spectrum/1997 (Sinclair_BASIC)" https://hudson.dev.java.net/
if [ "$?" != "0" ]; then
    echo "HTTPS protocol failed. Please configure 'https_proxy' environment variable:" | tee -a logs/${dttime}/setup_qs.log
    echo "" | tee -a logs/${dttime}/setup_qs.log
    echo "export https_proxy=proxy.server:port" | tee -a logs/${dttime}/setup_qs.log
    cd ..
    exit 2
fi
rm index.html

techo "Updating Ubuntu"
startpath=`pwd`
apt-get -y update
apt-get -y install build-essential linux-headers-`uname -r`

techo "Installing vmware-tools"
mount /media/cdrom0
cp /media/cdrom0/VMware* /tmp
cd /tmp
tar -zxf `ls *tar.gz`
cd vmware-tools-distrib
./vmware-install.pl < vmware-tools

techo "Reconfiguring timezone"
dpkg-reconfigure tzdata

techo "Updating GRUB"
cd ${startpath}
cp resources/grub.menu.lst /boot/grub/menu.lst
update-grub

techo "You MUST shutdown VM now and change .vmx file on the host: "
techo " tools.syncTime = \"TRUE\" "
