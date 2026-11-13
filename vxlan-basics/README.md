# VXLAN basics

Three leaves act as VXLAN tunnel endpoints (VTEPs) across a routed IPv4 network, stretching one layer 2 segment (VNI 100) between three hosts. MAC learning and a static flood list make the segment work without any control plane.
Blog post: *VXLAN: stretching a layer 2 network across a routed one*.

```
                   spine
           ┌─────────┼─────────┐
         leaf1     leaf2     leaf3     ← VTEPs, VNI 100
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

The leaves' eth2 ports have no address because they are bridge ports. Each leaf's VTEP address is its eth1 address.

## Requirements

- The shared lab environment listed in the [root README](../README.md#tested-with)
- The `vxlan` kernel module on the host

The nodes use a small image built from the official Alpine image with `iproute2` and
`tcpdump` (see `image/Containerfile`). Build it once:

```bash
sudo podman build -t localhost/vxlan-node:latest image/
```

## Deploy

```bash
sudo containerlab --runtime podman deploy -t topology.clab.yml
```

## Verify

```bash
sudo podman exec clab-vxlan-leaf1 bridge fdb show dev vxlan100
sudo podman exec clab-vxlan-h1 ping -c 2 192.168.100.2
sudo podman exec clab-vxlan-leaf1 bridge fdb show dev vxlan100
```

Expected: before the ping, leaf1's FDB only has the two all-zero flood entries
(and the bridge's own address). After it, there is a learned entry for h2's MAC
pointing at `dst 10.0.2.2`.

## Watch the tunnel

In one terminal, capture the VXLAN packets leaving leaf1 (7 packets for two pings):

```bash
sudo podman exec clab-vxlan-leaf1 tcpdump -nn -i eth1 udp port 4789 -v -c 7
```

In a second terminal, capture everything h3 receives, then ping from h1 to h2:

```bash
sudo podman exec clab-vxlan-h3 tcpdump -nn -i eth1
sudo podman exec clab-vxlan-h1 ping -c 2 192.168.100.2
```

Expected: the ARP request leaves leaf1 twice, once per remote VTEP, and the
ping packets only go to 10.0.2.2. h3 receives the ARP request and nothing else.

## Teardown

```bash
sudo containerlab --runtime podman destroy -t topology.clab.yml --cleanup
```
