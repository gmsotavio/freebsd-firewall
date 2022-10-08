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

ipfw -q -f flush

wan_if="vtnet0"
lan_if="vtnet1"

# CMD RULE_NUMBER set SET_NUMBER ACTION log LOG_AMOUNT PROTO from SRC SRC_PORT to DST DST_PORT OPTIONS

# NAT
ipfw disable one_pass
ipfw -q nat 1 config if ${wan_if} same_ports unreg_only reset

ipfw -q add 00010 allow all from any to any via lo0

ipfw -q add 00099 reass all from any to any in

# NAT any inbound packets
ipfw -q add 00100 nat 1 ip from any to any in via ${wan_if}

# Allow the packet through if it has an existing entry in the dynamic rules table
ipfw -q add 00101 check-state

ipfw -q add 00102 deny ip from any to any frag
ipfw -q add 00103 deny ip from any to any established

## Inbound rules for the WAN interface (01000 - 01499)

ipfw -q add 01301 allow icmp from any to me in recv ${wan_if} keep-state
ipfw -q add 01499 deny all from any to any in recv ${wan_if}

## Inbound rules for the LAN interface (01500 - 01999)

ipfw -q add 01501 allow tcp from any to me 22 in recv ${lan_if} keep-state
ipfw -q add 01701 allow icmp from 192.168.1.0/24 to me in recv ${lan_if} keep-state
ipfw -q add 01899 allow ip from 192.168.1.0/24 to \( not 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 or not me \) in recv ${lan_if} keep-state
ipfw -q add 01999 deny all from any to any in recv ${lan_if}

## Outbound rules for the WAN interface (02000 - 02499)

## Outbound rules for the LAN interface (02500 - 02999)

EOF

## Clarification about xmit recv via in out semantics
# https://lists.freebsd.org/pipermail/freebsd-questions/2005-July/094555.html
# https://lists.freebsd.org/pipermail/freebsd-questions/2005-July/094613.html
# https://lists.freebsd.org/pipermail/freebsd-ipfw/2018-January/006647.html
# https://groups.google.com/g/comp.unix.bsd.freebsd.misc/c/AkDSKlUmVok?pli=1
# https://lists.freebsd.org/pipermail/freebsd-ipfw/2005-September/002073.html

## Refereces
# https://www.asksaro.com/freebsd/setting-up-a-network-gateway-using-ipfw-and-natd/
# https://blog.socruel.nu/freebsd/how-to-implement-an-internet-facing-freebsd-ipfw-firewall.html
# https://www.usenix.org/legacy/publications/library/proceedings/bsdcon02/full_papers/lidl/lidl_html/index.html
# https://paulgorman.org/technical/freebsd-ipfw.txt.html
