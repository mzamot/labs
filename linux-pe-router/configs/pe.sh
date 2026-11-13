#!/bin/sh
# Turns an AlmaLinux VM into a PE router.
# Usage (as root, from the directory that holds this script): sh pe.sh N   (N is 1 to 9)
set -e
N=$1
case "$N" in
  [1-9]) ;;
  *) echo "usage: sh pe.sh N   (N is 1 to 9)"; exit 1 ;;
esac
# Per-node addresses. Each node owns 10.20.N.0/24 in the infra VRF.
HOST_L3=10.20.$N.2      # the host's routed link into infra
PE_L3=10.20.$N.1        # the PE end of that link
VTEP=10.20.$N.6         # the VTEP address
VTEP_GW=10.20.$N.5      # the PE end of the VTEP's link
MACHINE=10.10.100.1$N   # the host on the stretched LAN
SVI=10.10.100.25$N      # this node's own address on the stretched LAN
WL_PE=10.20.$N.9        # the PE end of the workloads handoff
WL=10.20.$N.10          # the workloads end
FRR=quay.io/frrouting/frr:10.7.1
DIR=$(cd "$(dirname "$0")" && pwd)

# The strict VRF mode sysctl below only exists once the vrf module is loaded
modprobe vrf
dnf install -y podman tcpdump
podman pull "$FRR"

ip netns add pe-router
ip netns add l2-vxlan

# ---------------------------------------------------------------------------
# pe-router: the fabric NIC, IS-IS, SRv6, and one VRF per service
# ---------------------------------------------------------------------------
ip link set eth1 netns pe-router
ip netns exec pe-router sh -c "
  sysctl -qw net.ipv6.conf.all.forwarding=1
  sysctl -qw net.ipv4.ip_forward=1
  sysctl -qw net.vrf.strict_mode=1
  sysctl -qw net.ipv4.conf.all.rp_filter=0
  sysctl -qw net.ipv4.conf.default.rp_filter=0
  ip link set lo up
  ip link set eth1 mtu 9000
  ip link set eth1 up
  ip addr add fc00:0:$N::1/128 dev lo
  ip link add infra type vrf table 10
  ip link add external type vrf table 20
  ip link set infra up
  ip link set external up
"
# The external VRF has no workloads yet. A test address stands in for future services.
ip -n pe-router link add ext-test type dummy
ip -n pe-router link set ext-test master external
ip -n pe-router addr add 192.0.2.$N/32 dev ext-test
ip -n pe-router link set ext-test up

# ---------------------------------------------------------------------------
# The host's routed path: default namespace <-> infra VRF, no VXLAN
# ---------------------------------------------------------------------------
ip link add ve-host-infra type veth peer name ve-infra-host
ip link set ve-infra-host netns pe-router
ip -n pe-router link set ve-infra-host master infra
ip -n pe-router addr add $PE_L3/30 dev ve-infra-host
ip -n pe-router link set ve-infra-host up
sysctl -qw net.ipv6.conf.ve-host-infra.disable_ipv6=1
ip addr add $HOST_L3/30 dev ve-host-infra
ip link set ve-host-infra up
ip route add 10.20.0.0/16 via $PE_L3

# ---------------------------------------------------------------------------
# The workloads handoff: a routed link from the workloads namespace into infra.
# Service prefixes are added behind it later, without changing this script.
# ---------------------------------------------------------------------------
ip netns add workloads
ip link add ve-wl-infra type veth peer name ve-infra-wl
ip link set ve-infra-wl netns pe-router
ip link set ve-wl-infra netns workloads
ip -n pe-router link set ve-infra-wl master infra
ip -n pe-router addr add $WL_PE/30 dev ve-infra-wl
ip -n pe-router link set ve-infra-wl up
ip netns exec workloads sysctl -qw net.ipv6.conf.all.disable_ipv6=1
ip -n workloads addr add $WL/30 dev ve-wl-infra
ip -n workloads link set lo up
ip -n workloads link set ve-wl-infra up
ip -n workloads route add default via $WL_PE

# ---------------------------------------------------------------------------
# l2-vxlan: VLAN-aware bridge, VXLAN (VNI 10100) and the anycast gateway
# ---------------------------------------------------------------------------
ip netns exec l2-vxlan sysctl -qw net.ipv6.conf.all.disable_ipv6=1
ip netns exec l2-vxlan sysctl -qw net.ipv6.conf.default.disable_ipv6=1
# The gateway routes between the stretched LAN and the infra VRF
ip netns exec l2-vxlan sysctl -qw net.ipv4.ip_forward=1
# The gateway receives on vlan100-gw, but its route to the LAN is on vlan100.
# Loose reverse-path filtering accepts that.
ip netns exec l2-vxlan sysctl -qw net.ipv4.conf.all.rp_filter=2
# Each interface answers ARP only for its own addresses, and sends ARP requests
# from its own address. This keeps the per-node and the anycast identities apart.
ip netns exec l2-vxlan sysctl -qw net.ipv4.conf.all.arp_ignore=1
ip netns exec l2-vxlan sysctl -qw net.ipv4.conf.all.arp_announce=2

# The VTEP's link into the infra VRF. It carries whole VXLAN packets, so it gets a large MTU.
ip link add ve-vtep-infra mtu 9000 type veth peer name ve-infra-vtep mtu 9000
ip link set ve-infra-vtep netns pe-router
ip link set ve-vtep-infra netns l2-vxlan
ip -n pe-router link set ve-infra-vtep master infra
ip -n pe-router addr add $VTEP_GW/30 dev ve-infra-vtep
ip -n pe-router link set ve-infra-vtep up
ip -n l2-vxlan addr add $VTEP/30 dev ve-vtep-infra

ip -n l2-vxlan link add br0 type bridge vlan_filtering 1 vlan_default_pvid 0 mcast_snooping 0
ip netns exec l2-vxlan bridge vlan add vid 100 dev br0 self

ip -n l2-vxlan link add vxlan10100 type vxlan id 10100 local $VTEP dstport 4789 nolearning
ip -n l2-vxlan link set vxlan10100 master br0
ip netns exec l2-vxlan bridge link set dev vxlan10100 learning off neigh_suppress on
ip netns exec l2-vxlan bridge vlan add dev vxlan10100 vid 100 pvid untagged master

# The host's port on the stretched LAN, untagged into VLAN 100
ip link add ve-host-br type veth peer name ve-br-host
ip link set ve-br-host netns l2-vxlan
ip netns exec l2-vxlan sysctl -qw net.ipv6.conf.all.disable_ipv6=1
ip -n l2-vxlan link set ve-br-host master br0
ip netns exec l2-vxlan bridge vlan add dev ve-br-host vid 100 pvid untagged master

# VLAN 100's own interface on this node, with a per-node address and MAC. The LAN's
# route uses it, so when the gateway looks up a host, the answer comes back here.
ip -n l2-vxlan link add vlan100 link br0 type vlan id 100
ip -n l2-vxlan addr add $SVI/24 dev vlan100

# Anycast gateway: the same IP and MAC on every node. noprefixroute leaves the
# LAN's route on vlan100.
ip -n l2-vxlan link add vlan100-gw link vlan100 type macvlan mode private
ip -n l2-vxlan link set vlan100-gw address 02:00:00:00:01:00
ip -n l2-vxlan addr add 10.10.100.1/24 dev vlan100-gw noprefixroute

for dev in lo ve-vtep-infra br0 vxlan10100 ve-br-host vlan100 vlan100-gw; do
  ip -n l2-vxlan link set "$dev" up
done
ip netns exec l2-vxlan bridge fdb add 02:00:00:00:01:00 dev br0 self local
ip -n l2-vxlan route add default via $VTEP_GW

# The host on the stretched LAN
sysctl -qw net.ipv6.conf.ve-host-br.disable_ipv6=1
# Traffic routed into the LAN arrives on ve-host-br, but the replies leave through
# ve-host-infra. Loose reverse-path filtering accepts that.
sysctl -qw net.ipv4.conf.ve-host-br.rp_filter=2
ip addr add $MACHINE/24 dev ve-host-br
ip link set ve-host-br up
# Workload services are reached through the anycast gateway
ip route add 10.250.0.0/16 via 10.10.100.1

# ---------------------------------------------------------------------------
# One FRR instance per namespace
# ---------------------------------------------------------------------------
mkdir -p /etc/frr/pe-router /etc/frr/l2-vxlan
cp "$DIR/daemons-router" /etc/frr/pe-router/daemons
cp "$DIR/daemons-l2" /etc/frr/l2-vxlan/daemons
cp "$DIR/vtysh.conf" /etc/frr/pe-router/
cp "$DIR/vtysh.conf" /etc/frr/l2-vxlan/
sed "s/@N@/$N/g" "$DIR/router.conf.in" > /etc/frr/pe-router/frr.conf
# node1's and node2's VTEPs are the EVPN route reflectors, each peering with the
# other; every other VTEP is a client of both
case "$N" in
  1) sed "s/@N@/1/g; s/@PEER@/2/g" "$DIR/l2-rr.conf.in" > /etc/frr/l2-vxlan/frr.conf ;;
  2) sed "s/@N@/2/g; s/@PEER@/1/g" "$DIR/l2-rr.conf.in" > /etc/frr/l2-vxlan/frr.conf ;;
  *) sed "s/@N@/$N/g" "$DIR/l2.conf.in" > /etc/frr/l2-vxlan/frr.conf ;;
esac
podman run -d --name frr-pe-router --hostname node$N-pe-router \
  --privileged --security-opt label=disable \
  --network ns:/var/run/netns/pe-router -v /etc/frr/pe-router:/etc/frr "$FRR"
podman run -d --name frr-l2-vxlan --hostname node$N-l2-vxlan \
  --privileged --security-opt label=disable \
  --network ns:/var/run/netns/l2-vxlan -v /etc/frr/l2-vxlan:/etc/frr "$FRR"
