#!/bin/sh

# Enumerate and select available Virtual Ethernet Adapters
clear
print "Available Virtual Ethernet adapter:"

for ent in  `lsdev -Cc adapter -S A -t IBM,l-lan -F name`
do
  print "\t ${ent}"
done
print "Enter your selection:   \b\c"
read adapter
if [[ -z "${adapter}" ]]
then
   adapter=ent0
fi

# setting chksum_offload
chdev -l ${adapter} -a chksum_offload=yes

# generate network interface name
num=`echo $adapter | sed 's/ent//'`
if=en${num}

hostname=''
ip=''
mask=''
gw=''

while [[ -z $hostname ]]
do
   print "Enter hostname:   \b\c"
   read hostname
done

while [[ -z $ip ]]
do
   print "Enter ip address:  \b\c" 
   read ip
done

while [[ -z $mask ]]
do 
  print "Enter netmask:  \b\c"
  read mask
done

while [[ -z $gw ]]
do
   print "Enter default gateway:  \b\c"
   read gw 
done

mktcpip -h $hostname -a $ip -i $if -m $mask -g $gw

# setup if
chdev -l $if -a mtu_bypass=on
chdev -l $if -a mtu=9000
ifconfig $if mtu 9000

# TCP/IP Stack tuning

no -p -o tcp_sendspace=262144 -o tcp_recvspace=262144 \
	-o udp_sendspace=65536 -o udp_recvspace=655360 \
	-o tcp_nodelayack=0 -o rfc1323=1 -o sack=1

