# SRv6 basics

Four routers and two hosts show SRv6 on plain Linux. r1 encapsulates traffic for h2 with a list of two segments: r3 (a waypoint) and r4 (the egress). r2 is an ordinary IPv6 router with no SRv6 configuration.
Blog post: *SRv6: segment routing over IPv6*.

```
 h1 ──── r1 ──── r2 ──── r3 ──── r4 ──── h2
        ingress  plain  waypoint egress
```

| Node | Interface | Address | Connected to |
|------|-----------|---------|--------------|
| h1 | eth1 | 10.1.1.2/24 | r1 |
| r1 | eth1 | 10.1.1.1/24 | h1 |
| r1 | eth2 | 2001:db8:12::1/64 | r2 |
| r1 | lo | fc00:0:1::1/128 | — |
| r2 | eth1 | 2001:db8:12::2/64 | r1 |
| r2 | eth2 | 2001:db8:23::1/64 | r3 |
| r2 | lo | fc00:0:2::1/128 | — |
| r3 | eth1 | 2001:db8:23::2/64 | r2 |
| r3 | eth2 | 2001:db8:34::1/64 | r4 |
| r3 | lo | fc00:0:3::1/128 | — |
| r4 | eth1 | 2001:db8:34::2/64 | r3 |
| r4 | eth2 | 10.2.2.1/24 | h2 |
| r4 | lo | fc00:0:4::1/128 | — |
| h2 | eth1 | 10.2.2.2/24 | r4 |

| Node | SID | Behavior |
|------|-----|----------|
| r3 | fc00:0:3::e | End |
| r4 | fc00:0:4::d | End.DX4, next hop 10.2.2.2 |
| r1 | fc00:0:1::d | End.DX4, next hop 10.1.1.2 |

## Requirements

- The shared lab environment listed in the [root README](../README.md#tested-with)
- SRv6 support in the host kernel (`seg6`). The compressed-SID (uSID) part needs a recent kernel.

The nodes use a small image built from the official Alpine image with `iproute2` and
`tcpdump` (see `image/Containerfile`). Build it once:

```bash
sudo podman build -t localhost/srv6-node:latest image/
```

## Deploy

```bash
sudo containerlab --runtime podman deploy -t topology.clab.yml
```

## Verify

```bash
sudo podman exec clab-srv6-r1 ip route show 10.2.2.0/24
sudo podman exec clab-srv6-r3 ip -6 route show | grep seg6
sudo podman exec clab-srv6-h1 ping -c 2 10.2.2.2
```

Expected: the ping succeeds and r1 shows an `encap seg6` route with two segments.

## Watch the packets

Capture on three links while h1 pings h2 (start the captures first, in separate terminals):

```bash
sudo podman exec clab-srv6-r2 tcpdump -nn -i eth1 -v ip6
sudo podman exec clab-srv6-r3 tcpdump -nn -i eth2 -v ip6
sudo podman exec clab-srv6-r4 tcpdump -nn -i eth2 -v
sudo podman exec clab-srv6-h1 ping -c 1 10.2.2.2
```

Expected: on r2's eth1 the outer destination is `fc00:0:3::e` with `segleft=1`; on r3's
eth2 it is `fc00:0:4::d` with `segleft=0`; on r4's eth2 the packet is plain IPv4.

## Try compressed segments (uSID)

These commands replace the segment lists with a single address and no routing header:

```bash
sudo podman exec clab-srv6-r3 ip -6 route add fc00:0:3::/48 \
  encap seg6local action End flavors next-csid lblen 32 nflen 16 dev eth1
sudo podman exec clab-srv6-r4 ip -6 route add fc00:0:4:d::/64 \
  encap seg6local action End.DX4 nh4 10.2.2.2 dev eth2
sudo podman exec clab-srv6-r4 ip route replace 10.1.1.0/24 \
  encap seg6 mode encap.red segs fc00:0:3:1:d:: dev eth1
sudo podman exec clab-srv6-r1 ip -6 route add fc00:0:1:d::/64 \
  encap seg6local action End.DX4 nh4 10.1.1.2 dev eth1
sudo podman exec clab-srv6-r1 ip route replace 10.2.2.0/24 \
  encap seg6 mode encap.red segs fc00:0:3:4:d:: dev eth2
sudo podman exec clab-srv6-h1 ping -c 2 10.2.2.2
```

## Teardown

```bash
sudo containerlab --runtime podman destroy -t topology.clab.yml --cleanup
```
