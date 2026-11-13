#!/bin/sh
# r4: SRv6 egress. Decapsulates traffic for h2 and encapsulates traffic for h1.
set -e
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

ip addr add 2001:db8:34::2/64 dev eth1
ip addr add 10.2.2.1/24 dev eth2
ip addr add fc00:0:4::1/128 dev lo

ip -6 route add fc00:0:1::/48 via 2001:db8:34::1
ip -6 route add fc00:0:2::/48 via 2001:db8:34::1
ip -6 route add fc00:0:3::/48 via 2001:db8:34::1

ip sr tunsrc set fc00:0:4::1

# Egress: decapsulate and hand the packet to h2
ip -6 route add fc00:0:4::d encap seg6local action End.DX4 nh4 10.2.2.2 dev eth2

# Return path: traffic for h1's network goes via r3 (End), then r1 (End.DX4)
ip route add 10.1.1.0/24 encap seg6 mode encap segs fc00:0:3::e,fc00:0:1::d dev eth1
