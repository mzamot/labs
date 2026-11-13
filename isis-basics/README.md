# IS-IS basics

Four FRR routers in a square, running IS-IS (Level-1, IPv4 and IPv6). One link has a
higher metric so you can watch shortest-path selection and failover.
Blog post: *IS-IS: how routers share a map of the network*.

```
   r1 ───────────────────── r2
   │                         │
   │ (metric 50)             │
   │                         │
   r4 ───────────────────── r3
```

| Node | Loopback (IPv4) | Loopback (IPv6) | NET |
|------|-----------------|-----------------|-----|
| r1 | 10.255.0.1/32 | 2001:db8:100::1/128 | 49.0001.0000.0000.0001.00 |
| r2 | 10.255.0.2/32 | 2001:db8:100::2/128 | 49.0001.0000.0000.0002.00 |
| r3 | 10.255.0.3/32 | 2001:db8:100::3/128 | 49.0001.0000.0000.0003.00 |
| r4 | 10.255.0.4/32 | 2001:db8:100::4/128 | 49.0001.0000.0000.0004.00 |

| Link | Node | Interface | IPv4 address | IPv6 address |
|------|------|-----------|--------------|--------------|
| r1–r2 | r1 | eth1 | 10.0.12.1/24 | 2001:db8:12::1/64 |
| r1–r2 | r2 | eth1 | 10.0.12.2/24 | 2001:db8:12::2/64 |
| r2–r3 | r2 | eth2 | 10.0.23.1/24 | 2001:db8:23::1/64 |
| r2–r3 | r3 | eth1 | 10.0.23.2/24 | 2001:db8:23::2/64 |
| r3–r4 | r3 | eth2 | 10.0.34.1/24 | 2001:db8:34::1/64 |
| r3–r4 | r4 | eth1 | 10.0.34.2/24 | 2001:db8:34::2/64 |
| r4–r1 (metric 50) | r4 | eth2 | 10.0.41.1/24 | 2001:db8:41::1/64 |
| r4–r1 (metric 50) | r1 | eth2 | 10.0.41.2/24 | 2001:db8:41::2/64 |

## Requirements

- A Linux host (bare metal or VM)
- [containerlab](https://containerlab.dev/install/) and a container runtime (Docker or podman)

Tested on Debian 13 with containerlab 0.83.0, podman 5.4 and the
`quay.io/frrouting/frr:10.7.1` image.

## Deploy

```bash
sudo containerlab deploy -t topology.clab.yml
# with podman:
sudo containerlab --runtime podman deploy -t topology.clab.yml
```

Allow a few seconds for IS-IS to converge.

## Verify

```bash
sudo podman exec clab-isis-r1 vtysh -c "show isis neighbor"
sudo podman exec clab-isis-r1 vtysh -c "show ip route isis"
sudo podman exec clab-isis-r1 vtysh -c "show ipv6 route isis"
sudo podman exec clab-isis-r1 ping -c 3 10.255.0.4
sudo podman exec clab-isis-r1 ping -6 -c 3 2001:db8:100::4
sudo podman exec clab-isis-r1 traceroute -n 10.255.0.4
```

Expected: two neighbors (r2, r4) in state `Up`, IS-IS routes for both address
families, and a traceroute to r4 that goes through r2 and r3 (cost 40) instead
of the direct link (cost 60).

Replace `sudo podman` with `docker` if you use Docker.

## Try a link failure

```bash
sudo podman exec clab-isis-r1 ip link set eth1 down
sudo podman exec clab-isis-r1 vtysh -c "show ip route 10.255.0.3/32"
sudo podman exec clab-isis-r1 vtysh -c "show ipv6 route 2001:db8:100::3/128"
sudo podman exec clab-isis-r1 ip link set eth1 up
```

Both routes to r3 move from `eth1` (metric 30) to `eth2` (metric 70).

## Teardown

```bash
sudo containerlab destroy -t topology.clab.yml --cleanup
```
