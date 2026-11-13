#!/bin/sh
# Prepares a leaf as a VXLAN tunnel endpoint (VTEP) for VNI 100.
# FRR handles the rest: it discovers the other VTEPs and advertises MAC addresses over BGP.
# Expects VTEP_IP and GATEWAY in the environment.
set -e

# Underlay: an address on the spine-facing link, and a route to the other leaves
ip addr add "$VTEP_IP/24" dev eth1
ip route add default via "$GATEWAY"

# Overlay: a bridge that joins the host-facing port and the VXLAN device.
# nolearning stops the VXLAN device from learning remote VTEPs from traffic;
# learning off stops the bridge from learning MACs on the VXLAN port.
ip link add br0 type bridge mcast_snooping 0
ip link add vxlan100 type vxlan id 100 local "$VTEP_IP" dstport 4789 nolearning
ip link set vxlan100 master br0
bridge link set dev vxlan100 learning off
ip link set eth2 master br0
ip link set br0 up
ip link set vxlan100 up
ip link set eth2 up
