#!/bin/sh
# r1: SRv6 ingress. Encapsulates traffic for h2 and decapsulates traffic for h1.
set -e
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

ip addr add 10.1.1.1/24 dev eth1
ip addr add 2001:db8:12::1/64 dev eth2
ip addr add fc00:0:1::1/128 dev lo

# Underlay: ordinary IPv6 routes to the other routers' locators
ip -6 route add fc00:0:2::/48 via 2001:db8:12::2
ip -6 route add fc00:0:3::/48 via 2001:db8:12::2
ip -6 route add fc00:0:4::/48 via 2001:db8:12::2

# Source address of the outer IPv6 header
ip sr tunsrc set fc00:0:1::1

# Ingress: traffic for h2's network gets a segment list: r3 (End), then r4 (End.DX4)
ip route add 10.2.2.0/24 encap seg6 mode encap segs fc00:0:3::e,fc00:0:4::d dev eth2

# Egress SID for the return path: decapsulate and hand the packet to h1
ip -6 route add fc00:0:1::d encap seg6local action End.DX4 nh4 10.1.1.2 dev eth1
