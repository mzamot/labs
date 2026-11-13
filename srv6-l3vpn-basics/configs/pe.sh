#!/bin/sh
# Prepares a PE: addresses, SRv6 sysctls, and one VRF per customer.
# FRR does the routing. Expects LOOPBACK, UPLINK, RED and BLUE in the environment.
set -e
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

ip addr add "$LOOPBACK/128" dev lo
ip addr add "$UPLINK/64" dev eth1

# The kernel requires strict VRF mode for SRv6 behaviors that look up a VRF table
sysctl -w net.vrf.strict_mode=1

# Reverse-path filtering on the VRF devices drops the packets that arrive through the
# SRv6 tunnel, so new interfaces, including the VRFs created below, start with it off
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.default.rp_filter=0

# One VRF per customer, with the customer-facing interface attached
ip link add red type vrf table 10
ip link add blue type vrf table 20
ip link set red up
ip link set blue up
ip link set eth2 master red
ip link set eth3 master blue
ip addr add "$RED/24" dev eth2
ip addr add "$BLUE/24" dev eth3
