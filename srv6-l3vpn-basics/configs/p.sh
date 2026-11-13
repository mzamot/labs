#!/bin/sh
# P: a plain IPv6 router. No SRv6 and no BGP.
set -e
sysctl -w net.ipv6.conf.all.forwarding=1

ip addr add 2001:db8:1::2/64 dev eth1
ip addr add 2001:db8:2::1/64 dev eth2

ip -6 route add fc00:0:1::/48 via 2001:db8:1::1
ip -6 route add fc00:0:2::/48 via 2001:db8:2::2
