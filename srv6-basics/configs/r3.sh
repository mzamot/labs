#!/bin/sh
# r3: an SRv6 waypoint. Its End SID advances the segment list.
set -e
sysctl -w net.ipv6.conf.all.forwarding=1

ip addr add 2001:db8:23::2/64 dev eth1
ip addr add 2001:db8:34::1/64 dev eth2
ip addr add fc00:0:3::1/128 dev lo

ip -6 route add fc00:0:1::/48 via 2001:db8:23::1
ip -6 route add fc00:0:2::/48 via 2001:db8:23::1
ip -6 route add fc00:0:4::/48 via 2001:db8:34::2

# End: process the segment list and forward to the next segment
ip -6 route add fc00:0:3::e encap seg6local action End dev eth1
