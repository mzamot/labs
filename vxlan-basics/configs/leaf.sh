#!/bin/sh
# Configures a leaf as a VXLAN tunnel endpoint (VTEP) for VNI 100.
# Expects VTEP_IP, GATEWAY and REMOTE_VTEPS in the environment.
set -e

# Underlay: an address on the spine-facing link, and a route to the other leaves
ip addr add "$VTEP_IP/24" dev eth1
ip route add default via "$GATEWAY"

# Overlay: a bridge that joins the host-facing port and the VXLAN device
ip link add br0 type bridge mcast_snooping 0
ip link add vxlan100 type vxlan id 100 local "$VTEP_IP" dstport 4789
ip link set vxlan100 master br0
ip link set eth2 master br0
ip link set br0 up
ip link set vxlan100 up
ip link set eth2 up

# Flood list: send broadcast, unknown-unicast and multicast frames to every remote VTEP
for vtep in $REMOTE_VTEPS; do
  bridge fdb append 00:00:00:00:00:00 dev vxlan100 dst "$vtep"
done
