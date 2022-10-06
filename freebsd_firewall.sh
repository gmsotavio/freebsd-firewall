#!/bin/sh

## Configuring the network interfaces
# https://docs.freebsd.org/en/books/handbook/config/#_configuring_the_network_card
sysrc ifconfig_vtnet0="DHCP"
sysrc ifconfig_vtnet1="inet 192.168.1.1 netmask 255.255.255.0"

## Setup DHCP server
# https://docs.freebsd.org/en/books/handbook/network-servers/#network-dhcp

# Install DHCP server
pgk install isc-dhcp44-server/pkg-descr

# Create a configuration file based on the example
cp /usr/local/etc/dhcpd.conf.sample /usr/local/etc/dhcpd.conf 

cat << EOF > /usr/local/etc/dhcpd.conf
# dhcpd.conf
#
# Configuration file for ISC dhcpd for FreeBSD.
# 

option domain-name "example.org";
option domain-name-servers 8.8.8.8, 8.8.4.4;
option subnet-mask 255.255.255.0;

default-lease-time 600;
max-lease-time 7200;
ddns-update-style none;

subnet 192.168.1.0 netmask 255.255.255.0 {
  range 192.168.1.100 192.168.1.200;
  option routers 192.168.1.1;
}

host fantasia {
  hardware ethernet 08:00:07:26:c0:a5;
  fixed-address 192.168.1.10; 
}
EOF

sysrc dhcpd_enable="YES"

# Select the listening interface
sysrc dhcpd_ifaces="vtnet1"
	
# Start the DHCP service
service isc-dhcpd start

# Check DHCP leases
#https://www.freebsd.org/cgi/man.cgi?query=dhclient.leases&sektion=5&format=html
#cat /var/db/dhclient.leases.IFNAME

## Setup SSHD


## Configure static routes
# https://docs.freebsd.org/en/books/handbook/advanced-networking/#network-routing
# https://www.cyberciti.biz/faq/freebsd-setup-default-routing-with-route-command/
# https://www.cyberciti.biz/faq/howto-freebsd-configuring-static-routes/

# Check current IPV4 routes 
# netstat -4 -n -r

# Default route
sysrc defaultrouter="192.168.122.1"

# Static routes for internal network
#static_routes="net1 net2"
#route_net1="-net 192.168.0.0/24 192.168.0.1"
#route_net2="-net 192.168.1.0/24 192.168.1.1"

# Turn FreeBSD as router
sysctl net.inet.ip.forwarding=1
#sysctl net.inet6.ip6.forwarding=1

sysrc gateway_enable="YES"
#sysrc ipv6_gateway_enable=yes

# /etc/rc.d/netif restart
service netif restart
# /etc/rc.d/routing restart
service routing restart


## Firewall configuration
# https://docs.freebsd.org/pt-br/books/handbook/firewalls/#firewalls-ipfw

#Enable IPFW
sysrc firewall_enable="YES"
sysrc firewall_script="/etc/ipfw.rules"
sysrc firewall_logging="YES"

#Enable in-kernel NAT facility
sysrc firewall_nat_enable="YES"

sysctl net.inet.tcp.tso=0
sysctl net.inet.ip.fw.one_pass=0

# Start IPFW service
service ipfw start

# Unlimited logging.
sysctl net.inet.ip.fw.verbose_limit=0

cat << EOF > /etc/ipfw.rules
#!/bin/sh

ipfw -f flush

wan_if="vtnet0"
lan_if="vtnet1"

# CMD RULE_NUMBER set SET_NUMBER ACTION log LOG_AMOUNT PROTO from SRC SRC_PORT to DST DST_PORT OPTIONS

# NAT
ipfw disable one_pass
ipfw -q nat 1 config if $wan_if same_ports unreg_only reset

ipfw -q add 00005 allow all from any to any via $lan_if

# NAT any inbound packets
ipfw -q add 00100 nat 1 ip from any to any in via $pif

# Allow the packet through if it has an existing entry in the dynamic rules table
ipfw -q add 00101 check-state
EOF

## Clarification about xmit recv via in out semantics
# https://lists.freebsd.org/pipermail/freebsd-questions/2005-July/094613.html
# https://lists.freebsd.org/pipermail/freebsd-ipfw/2018-January/006647.html
# https://groups.google.com/g/comp.unix.bsd.freebsd.misc/c/AkDSKlUmVok?pli=1 
