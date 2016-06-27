#!/bin/bash
clear

echo -e "##########################################################################"
echo -e "#                      AUTO SCRIPT PRE-INSTALL ZIMBRA                    #"
echo -e "##########################################################################"

echo ""
echo -e "Pastikan server terhubung ke internet untuk meng-install package. Jika tidak menggunakan koneksi internet, mohon konfigurasikan repository dari DVD"
echo ""
echo -e "Tekan tombol Enter"
read presskey

# Disable Selinux & Firewall

echo -e "[INFO] : Meng-konfigurasikan Firewall & Selinux"
sed -i s/'SELINUX'/'#SELINUX'/g /etc/sysconfig/selinux
echo 'SELINUX=disabled' >> /etc/sysconfig/selinux
setenforce 0
service firewalld stop
service iptables stop
service ip6tables stop
systemctl disable firewalld
systemctl disable iptables
systemctl disable ip6tables

# Configuring network, /etc/hosts and resolv.conf

echo ""
echo -e "[INFO] : Meng-konfigurasikan network, /etc/hosts dan resolv.conf"
echo -e "[INFO] : Memeriksa interface yang available"
echo ""

ifconfig -a
echo ""

echo -n "Masukkan interface yang akan digunakan (misalkan: ens32) : "
read INTERFACES
echo -n "Masukkan nama Hostname. (misalkan: mail) : "
read HOSTNAME
echo -n "Masukkan nama Domain. (misalkan: andalasmedia.net.id) : "
read DOMAIN
echo -n "Masukkan IP Address : "
read IPADDRESS
echo -n "Masukkan Netmask. (misalkan: 255.255.255.0) : "
read NETMASK
echo -n "Masukkan Gateway : "
read GATEWAY
echo -n "Masukkan Nameserver 2. (misalkan IP Gateway/DNS ISP) : "
read DNS2
echo -n "Masukkan Nameserver 3. (misalkan Google DNS 8.8.8.8) : "
read DNS3
echo ""

# Configuring Network

IFACE=`ls /etc/sysconfig/network-scripts/ | grep ifcfg-$INTERFACES.back`;

        if [ "$IFACE" == "ifcfg-$INTERFACES.back" ]; then
        cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACES.back /etc/sysconfig/network-scripts/ifcfg-$INTERFACES
        else
        cp /etc/sysconfig/network-scripts/ifcfg-$INTERFACES /etc/sysconfig/network-scripts/ifcfg-$INTERFACES.back
        fi

echo "DEVICE=$INTERFACES" > /etc/sysconfig/network-scripts/ifcfg-$INTERFACES
echo "ONBOOT=yes" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACES
echo "NM_CONTROLLED=no" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACES
echo "BOOTPROTO=none" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACES
echo "IPADDR=$IPADDRESS" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACES
echo "NETMASK=$NETMASK" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACES
echo "DNS1=$IPADDRESS" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACES
echo "GATEWAY=$GATEWAY" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACES
echo "DNS2=$DNS2" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACES
echo "USERCTL=no" >> /etc/sysconfig/network-scripts/ifcfg-$INTERFACES

# /etc/hosts

cp /etc/hosts /etc/hosts.backup

echo "127.0.0.1       localhost" > /etc/hosts
echo "$IPADDRESS   $HOSTNAME.$DOMAIN       $HOSTNAME" >> /etc/hosts

# Change Hostname
hostname $HOSTNAME
sed -i '/HOSTNAME=*/d' /etc/sysconfig/network
echo "HOSTNAME=$HOSTNAME.$DOMAIN" >> /etc/sysconfig/network

# /etc/resolv.conf
cp /etc/resolv.conf /etc/resolv.conf.back

echo "search $DOMAIN" > /etc/resolv.conf
echo "nameserver $IPADDRESS" >> /etc/resolv.conf
echo "nameserver $DNS2" >> /etc/resolv.conf
echo "nameserver $DNS3" >> /etc/resolv.conf

# Restart service Network and testing connection

service network restart
ping -c7 $GATEWAY
chkconfig network on

# Disable service sendmail or postfix

service sendmail stop
service postfix stop
systemctl disable sendmail
systemctl disable postfix

# Update repo and install package needed by Zimbra

yum update
yum -y install perl perl-core wget screen w3m elinks openssh-clients openssh-server bind bind-utils unzip nmap sed nc sysstat libaio rsync telnet aspell


# Configuring DNS Server

echo ""
echo -e "[INFO] : Meng-konfigurasikan DNS Server"
echo ""

NAMED=`ls /etc/ | grep named.conf.back`;

        if [ "$NAMED" == "named.conf.back" ]; then
        cp /etc/named.conf.back /etc/named.conf        
        else
        cp /etc/named.conf /etc/named.conf.back        
        fi

sed -i s/"listen-on port 53 { 127.0.0.1; };"/"listen-on port 53 { 127.0.0.1; any; };"/g /etc/named.conf
sed -i s/"allow-query     { localhost; };"/"allow-query     { localhost; any; };"/g /etc/named.conf

echo 'zone "'$DOMAIN'" IN {' >> /etc/named.conf
echo "        type master;" >> /etc/named.conf
echo '        file "'db.$DOMAIN'";' >> /etc/named.conf
echo "        allow-update { none; };" >> /etc/named.conf
echo "};" >> /etc/named.conf

touch /var/named/db.$DOMAIN
chgrp named /var/named/db.$DOMAIN

echo '$TTL 1D' > /var/named/db.$DOMAIN
echo "@       IN SOA  ns1.$DOMAIN. root.$DOMAIN. (" >> /var/named/db.$DOMAIN
echo '                                        0       ; serial' >> /var/named/db.$DOMAIN
echo '                                        1D      ; refresh' >> /var/named/db.$DOMAIN
echo '                                        1H      ; retry' >> /var/named/db.$DOMAIN
echo '                                        1W      ; expire' >> /var/named/db.$DOMAIN
echo '                                        3H )    ; minimum' >> /var/named/db.$DOMAIN
echo "@         IN      NS      ns1.$DOMAIN." >> /var/named/db.$DOMAIN
echo "@         IN      MX      0 $HOSTNAME.$DOMAIN." >> /var/named/db.$DOMAIN
echo "ns1       IN      A       $IPADDRESS" >> /var/named/db.$DOMAIN
echo "$HOSTNAME IN      A       $IPADDRESS" >> /var/named/db.$DOMAIN

# Restart Service & Check results configuring DNS Server

service named restart
systemctl enable named
nslookup $HOSTNAME.$DOMAIN
dig $DOMAIN mx

echo ""
echo "Meng-konfigurasikan Firewall, network, /etc/hosts dan DNS server telah selesai. Silahkan install Zimbra sekarang"
