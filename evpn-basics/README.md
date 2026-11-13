# EVPN basics

Three leaves run FRR and use BGP EVPN as the control plane for a VXLAN segment (VNI 100) across a routed IPv4 network. There is no static flood list and no learning from tunnel traffic: the leaves discover each other and exchange MAC addresses over BGP.
Blog post: *EVPN: a BGP control plane for VXLAN*.

```
                   spine
           ┌─────────┼─────────┐
         leaf1     leaf2     leaf3     ← VTEPs (FRR), iBGP AS 65000, VNI 100
           │         │         │
          h1        h2        h3       ← 192.168.100.0/24
```

| Node | Interface | IPv4 address | Connected to |
|------|-----------|--------------|--------------|
| spine | eth1 | 10.0.1.1/24 | leaf1 |
| spine | eth2 | 10.0.2.1/24 | leaf2 |
| spine | eth3 | 10.0.3.1/24 | leaf3 |
| leaf1 | eth1 | 10.0.1.2/24 | spine |
| leaf1 | eth2 | — | h1 |
| leaf2 | eth1 | 10.0.2.2/24 | spine |
| leaf2 | eth2 | — | h2 |
| leaf3 | eth1 | 10.0.3.2/24 | spine |
| leaf3 | eth2 | — | h3 |
| h1 | eth1 | 192.168.100.1/24 | leaf1 |
| h2 | eth1 | 192.168.100.2/24 | leaf2 |
| h3 | eth1 | 192.168.100.3/24 | leaf3 |

The leaves' eth2 ports have no address because they are bridge ports. Each leaf's VTEP address is its eth1 address, and the leaves peer with each other using those addresses. The spine only forwards IP and does not run BGP.

## Requirements

- The shared lab environment listed in the [root README](../README.md#tested-with)
- The `vxlan` kernel module on the host

The leaves use the official FRR image (`quay.io/frrouting/frr:10.7.1`). The spine and hosts use a
small image built from the official Alpine image with `iproute2` and `tcpdump` (see
`image/Containerfile`). Build it once:

```bash
sudo podman build -t localhost/evpn-node:latest image/
```

## Deploy

```bash
sudo containerlab --runtime podman deploy -t topology.clab.yml
```

Allow a few seconds for the BGP sessions to establish.

## Verify

```bash
sudo podman exec clab-evpn-leaf1 vtysh -c "show bgp l2vpn evpn summary"
sudo podman exec clab-evpn-leaf1 vtysh -c "show evpn vni 100"
sudo podman exec clab-evpn-leaf1 bridge fdb show dev vxlan100
sudo podman exec clab-evpn-h1 ping -c 2 192.168.100.2
sudo podman exec clab-evpn-leaf3 vtysh -c "show bgp l2vpn evpn route type macip"
sudo podman exec clab-evpn-leaf3 bridge fdb show dev vxlan100
```

Expected: both BGP neighbors established, two remote VTEPs with `flood: HER` on
every leaf before any traffic, and after the ping, two type-2 routes on leaf3
(h1's and h2's MAC) and entries for both MAC addresses in leaf3's FDB, marked `extern_learn`.

## Watch the second ping

After the first ping, ping again while capturing toward leaf3. Nothing should
be sent to leaf3 or h3:

```bash
sudo podman exec clab-evpn-spine tcpdump -nn -i eth3 udp port 4789
sudo podman exec clab-evpn-h3 tcpdump -nn -i eth1
sudo podman exec clab-evpn-h1 ping -c 2 192.168.100.2
```

## Teardown

```bash
sudo containerlab --runtime podman destroy -t topology.clab.yml --cleanup
```
