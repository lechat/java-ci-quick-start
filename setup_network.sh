#!/bin/bash
if [ "$(whoami)" != "root" ]; then
	echo "Sorry, you need to run this script as root. Use: sudo ./setup_network.sh"
	exit 1
fi

rm /etc/udev/rules.d/70-persistent-net.rules
/etc/init.d/networking restart
apt-get -y install ssh
