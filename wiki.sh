#!/bin/bash
#************************************************#
# setup_qs.sh# written by Aleksey Maksimov       
# (c) 2009 Capgemini UK plc.
#
# Installs and pre-configures Project QuickStart servers
# 
# All logs are written to logs/<<date and time>>/ folder.
#************************************************#
down ()
{
    if [ ! -e "${startdir}/download" ]; then
        mkdir ${startdir}/download
    fi
    cd ${startdir}/download
    
    # User-agent string needs to be replaced because Maven repository doesn't allow to use wget
    # It detects wget by user-agent string.
    # Used ZX_Spectrum just for fun
    wget -U "ZX_Spectrum/1997 (Sinclair_BASIC)" $1 >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
    if [ "$?" != "0" ]; then
        echo "Failed to download $1. More details in setup_qs.log. Exiting." | tee -a ${startdir}/logs/${dttime}/setup_qs.log
        cd ..
        exit 3
    fi
    cd ..
}

techo () 
{
    echo "`date +"%y-%m-%d %H:%M:%S"` - $1" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
}

aptget ()
{
    apt-get -y install $1 >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
    if [ "$?" != "0" ]; then
        echo "Failed to install. More details in setup_qs.log. Exiting." | tee -a ${startdir}/logs/${dttime}/setup_qs.log
        exit 3
    fi
}

dttime=`date +"%y%m%d_%H%M%S"`
startdir=`pwd`
mkdir -p ${startdir}/logs/${dttime}/
techo "Started at `date`"
if [ "$(whoami)" != "root" ]; then
    echo "Sorry, you need to run this script as root. Use: sudo ./setup_qs.sh" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    exit 1
fi

techo "Checking if HTTP and HTTPS working properly"
wget -U "ZX_Spectrum/1997 (Sinclair_BASIC)" http://www.google.com/ >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
if [ "$?" != "0" ]; then
    echo "HTTP protocol failed. Please configure 'http_proxy' environment variable:" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    echo "" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    echo "export http_proxy=proxy.server:port" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    cd ..
    exit 2
fi
rm index.html

wget -U "ZX_Spectrum/1997 (Sinclair_BASIC)" https://hudson.dev.java.net/ >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
if [ "$?" != "0" ]; then
    echo "HTTPS protocol failed. Please configure 'https_proxy' environment variable:" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    echo "" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    echo "export https_proxy=proxy.server:port" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    cd ..
    exit 2
fi
rm index.html

techo "Installing MediaWiki"
techo "Preparing MySQL"
techo "    Stopping MySQL"
service mysql stop >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
techo "    Starting MySQL in special mode"
mysqld --skip-grant-tables &

techo "    Running MySQL script"
mysqlready=1
while [ ${mysqlready} != 0 ]
do
   mysql < resources/mysql-init >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
   mysqlready=$?
done

techo "    Stopping MySQL"
service mysql stop >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
techo "    Starting MySQL"
service mysql start >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

techo "Installing PHP"
aptget "php5 php5-cli php5-common php5-mysql libapache2-mod-php5"

techo "Downloading and Configuring MediaWiki"
if [ ! -e "download/mediawiki-1.14.0.tar.gz" ]; then
   down http://download.wikimedia.org/mediawiki/1.14/mediawiki-1.14.0.tar.gz
fi
cd /var/www
tar xvfz ${startdir}/download/mediawiki-1.14.0.tar.gz >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
mv mediawiki-1.14.0/ wiki/

cd ${startdir}
cp resources/wiki.localsettings.php /var/www/wiki/LocalSettings.php
cp resources/logo.png /var/www/wiki/
cp resources/AdminSettings.php /var/www/wiki/
chown -R www-data\: /var/www/wiki/

techo "Populating Wiki" 
mysql wikidb -u root --password=qu1ckstart < resources/wikidb.ready.dump

php /var/www/wiki/maintenance/rebuildrecentchanges.php  >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

techo "Configuring SSH public key"
mkdir ${startdir}/.ssh
cp resources/authorized_keys2 ${startdir}/.ssh/authorized_keys2
chmod -R og= ${startdir}/.ssh/
chown -R tuxdistro\: ${startdir}/.ssh/

techo "Editing MOTD"
cp resources/motd.tail /etc/motd.tail

techo "All finished"
