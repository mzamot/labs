#!/bin/sh
# r2: a plain IPv6 router. No SRv6 configuration at all.
set -e
sysctl -w net.ipv6.conf.all.forwarding=1

ip addr add 2001:db8:12::2/64 dev eth1
ip addr add 2001:db8:23::1/64 dev eth2
ip addr add fc00:0:2::1/128 dev lo

ip -6 route add fc00:0:1::/48 via 2001:db8:12::1
ip -6 route add fc00:0:3::/48 via 2001:db8:23::2
ip -6 route add fc00:0:4::/48 via 2001:db8:23::2
