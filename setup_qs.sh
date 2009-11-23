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
    wget -U "ZX_Spectrum/1997 (Sinclair_BASIC)" -nv --no-check-certificate $1 >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
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

checkinstall() 
{
    techo "Checking installation of $1"
    dpkg -s $1 >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
    if [ "$?" != "0" ]; then
        techo "$1 is not installed. Installing now."
        aptget $1
    else
        techo "Already installed"
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

checkinstall "wget"
checkinstall "apache2"
checkinstall "mysql-server"

techo "Checking if HTTP and HTTPS working properly"
wget -U "ZX_Spectrum/1997 (Sinclair_BASIC)" --spider http://www.google.com/ >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
if [ "$?" != "0" ]; then
    echo "HTTP protocol failed. Please configure 'http_proxy' environment variable:" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    echo "" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    echo "export http_proxy=proxy.server:port" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    cd ..
    exit 2
fi

wget -U "ZX_Spectrum/1997 (Sinclair_BASIC)" --spider --no-check-certificate https://hudson.dev.java.net/ >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
if [ "$?" != "0" ]; then
    echo "HTTPS protocol failed. Please configure 'https_proxy' environment variable:" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    echo "" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    echo "export https_proxy=proxy.server:port" | tee -a ${startdir}/logs/${dttime}/setup_qs.log
    cd ..
    exit 2
fi

techo "Updating repositories"
apt-get -y update  >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
techo "Installing Subversion"
aptget "subversion subversion-tools libapache2-svn"
mkdir -p /var/lib/svn
chown -R www-data.www-data /var/lib/svn

techo "Configuring Apache to use Subversion"
cp resources/dav_svn.conf /etc/apache2/mods-available/dav_svn.conf
cp resources/initial-svn-users /etc/svn-auth-file

techo "Creating Demo project Subversion repository"
rm -rf /var/lib/svn/cappdemo
mkdir /var/lib/svn/
svnadmin create /var/lib/svn/cappdemo
mkdir ./demo
svn export http://www.minimalsoftware.com/sandpit/build_demo_1 demo/
mkdir demo/branches
mkdir demo/tags
sudo svn import demo/ file:///var/lib/svn/cappdemo/ -m "Initial import"

cd ${startdir}

techo "Installing Sun JDK6"
/usr/bin/debconf-set-selections resources/accept.jdk.txt
aptget "sun-java6-jdk"
update-java-alternatives -s java-6-sun >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

techo "Installing Tomcat6"
aptget "tomcat6 ecj ant libgcj9-dbg libgcj9-0-awt tomcat6-docs tomcat6-admin tomcat6-examples libapache2-mod-jk"
cp resources/tomcat-users.xml /etc/tomcat6/tomcat-users.xml

techo "Installing mod_jk"
cp resources/jk.conf /etc/apache2/mods-available/
cp resources/workers.properties /etc/apache2/

a2dismod jk >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
a2enmod jk >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

#######################################
# /etc/init.d/apache2 restart

techo "Installing maven2"
aptget "maven2"

techo "Downloading Hudson"
down "http://hudson.gotdns.com/latest/hudson.war"

techo "Prepare Hudson folder"
mkdir /srv/hudson
chown tomcat6.tomcat6 /srv/hudson/

techo "Copy Hudson"
cp download/hudson.war /var/lib/tomcat6/webapps/
chown tomcat6.tomcat6 /var/lib/tomcat6/webapps/hudson.war

techo "Reconfiguring Tomcat for Hudson"
mv /etc/default/tomcat6 /etc/default/tomcat6.backup
cp resources/tomcat6 /etc/default/tomcat6

##########################################
service tomcat6 restart >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

techo "Adding Hudson to Apache"
cp resources/hudson.site /etc/apache2/sites-available/hudson
a2dissite hudson >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
a2ensite hudson >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

##########################################
# /etc/init.d/apache2 restart

techo "Installing Trac"
aptget "libapache2-mod-python python-setuptools python-subversion"
easy_install Trac >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

cd ${startdir}
techo "Creating Trac repository for Demo project"
mkdir /var/lib/trac
trac-admin /var/lib/trac/demo initenv < resources/trac_capp_init  >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
chown -R www-data:www-data /var/lib/trac

techo "Adding Trac to Apache"
cp resources/trac.site /etc/apache2/sites-available/trac
a2dissite trac >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
a2ensite trac >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

##########################
# service apache2 restart

techo "Configuring Artifactory"
service tomcat6 stop >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
techo "Downloading Artifactory"
down "http://kent.dl.sourceforge.net/sourceforge/artifactory/artifactory-2.0.5.war"
cp download/artifactory-2.0.5.war /var/lib/tomcat6/webapps/artifactory.war
chown -R tomcat6.tomcat6 /usr/share/tomcat6/
service tomcat6 start >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

techo "Adding Artifactory to Apache"
cp resources/artifactory.site /etc/apache2/sites-available/artifactory
a2dissite artifactory >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
a2ensite artifactory >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

###############################
service apache2 restart >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

techo "Configuring Maven to use local repository"
cp resources/maven.settings.xml /etc/maven2/settings.xml

# We need to wait for Artifactory in order to work
srvready=1
while [ ${srvready} != 0 ]
do
   techo "    Waiting for server to become ready..."
   wget -q http://localhost/artifactory/webapp/browserepo.html >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
   srvready=$?
   sleep 5
done

rm browserepo.html
techo "Adding libraries required by Demo"
mvn deploy:deploy-file -DgroupId=javax.activation -DartifactId=activation -Dversion=1.0.2 -Dpackaging=jar -Dfile=resources/activation.jar -Durl=http://localhost/artifactory/repo1 -DrepositoryId=artifactory  >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
mvn deploy:deploy-file -DgroupId=el-impl -DartifactId=el-impl -Dversion=1.0 -Dpackaging=jar -Dfile=resources/el-impl-1.0.jar -Durl=http://localhost/artifactory/repo1 -DrepositoryId=artifactory >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
mvn deploy:deploy-file  -DgroupId=javax.transaction -DartifactId=jta -Dversion=1.0.1B -Dpackaging=jar -Dfile=resources/jta-1_0_1B.jar -Durl=http://localhost/artifactory/repo1 -DrepositoryId=artifactory >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

service tomcat6 stop >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

techo "Adding CAPP jobs to Hudson"
mkdir -p /srv/hudson/jobs/CAPP-demo-application-service-impl/
cp resources/CAPP-demo-application-service-impl.config.xml /srv/hudson/jobs/CAPP-demo-application-service-impl/config.xml
mkdir -p /srv/hudson/jobs/CAPP-demo-dal/
cp resources/CAPP-demo-dal.config.xml /srv/hudson/jobs/CAPP-demo-dal/config.xml
mkdir -p /srv/hudson/jobs/CAPP-demo-domain/
cp resources/CAPP-demo-domain.config.xml /srv/hudson/jobs/CAPP-demo-domain/config.xml
mkdir -p /srv/hudson/jobs/CAPP-demo-service-api/
cp resources/CAPP-demo-service-api.config.xml /srv/hudson/jobs/CAPP-demo-service-api/config.xml
mkdir -p /srv/hudson/jobs/CAPP-demo-service-impl/
cp resources/CAPP-demo-service-impl.config.xml /srv/hudson/jobs/CAPP-demo-service-impl/config.xml
mkdir -p /srv/hudson/jobs/CAPP-demo-service-springws-client/
cp resources/CAPP-demo-service-springws-client.config.xml /srv/hudson/jobs/CAPP-demo-service-springws-client/config.xml
mkdir -p /srv/hudson/jobs/CAPP-demo-service-springws-common/
cp resources/CAPP-demo-service-springws-common.config.xml /srv/hudson/jobs/CAPP-demo-service-springws-common/config.xml
mkdir -p /srv/hudson/jobs/CAPP-demo-service-springws-server/
cp resources/CAPP-demo-service-springws-server.config.xml /srv/hudson/jobs/CAPP-demo-service-springws-server/config.xml
mkdir -p /srv/hudson/jobs/CAPP-demo-validation-rule-framework/
cp resources/CAPP-demo-validation-rule-framework.config.xml /srv/hudson/jobs/CAPP-demo-validation-rule-framework/config.xml
mkdir -p /srv/hudson/jobs/CAPP-demo-webapp-jsf/
cp resources/CAPP-demo-webapp-jsf.config.xml /srv/hudson/jobs/CAPP-demo-webapp-jsf/config.xml
mkdir -p /srv/hudson/jobs/CAPP-Integration/
cp resources/CAPP-Integration.config.xml /srv/hudson/jobs/CAPP-Integration/config.xml
mkdir -p /srv/hudson/jobs/CAPP-Site/
cp resources/CAPP-Site.config.xml /srv/hudson/jobs/CAPP-Site/config.xml
cp resources/hudson.config.tar.gz /srv/hudson/

techo "Downloading Hudson plugins"
techo "    Emma..."
down "http://hudson.dev.java.net/files/documents/2402/62566/emma.hpi" 
techo "    Trac..."
down "http://hudson.dev.java.net/files/documents/2402/127186/trac.hpi"
techo "    Checkstyle..."
down "http://hudson.dev.java.net/files/documents/2402/131276/checkstyle.hpi"
techo "    Cobertura..."
down "http://hudson.dev.java.net/files/documents/2402/122688/cobertura.hpi"
techo "    FindBugs..."
down "http://hudson.dev.java.net/files/documents/2402/131279/findbugs.hpi"

cp download/emma.hpi /srv/hudson/plugins/
cp download/trac.hpi /srv/hudson/plugins/
cp download/checkstyle.hpi /srv/hudson/plugins/
cp download/cobertura.hpi /srv/hudson/plugins/
cp download/findbugs.hpi /srv/hudson/plugins/

cd /srv/hudson/
tar xvfz hudson.config.tar.gz  >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1
rm hudson.config.tar.gz

chown -R tomcat6\: /srv/hudson/
cd ${startdir}

service tomcat6 start >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

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

techo "Starting Integration Build"
wget -U "ZX_Spectrum/1997 (Sinclair_BASIC)" --spider http://localhost/hudson/job/CAPP-Integration/build?delay=0sec >> ${startdir}/logs/${dttime}/setup_qs.log 2>&1

techo "All finished"
