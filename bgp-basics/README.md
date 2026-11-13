# BGP basics

Four FRR routers in a line, running BGP over both IPv4 and IPv6. r2 and r3 share an AS
(iBGP); the other links are eBGP. Every router advertises one prefix per
address family, so you can see AS paths, next hops, and what happens when a
session goes down.
Blog post: *BGP: how networks tell each other what they can reach*.

```
  AS 65001        AS 65002        AS 65002        AS 65003
     r1 ──────────── r2 ──────────── r3 ──────────── r4
          eBGP            iBGP            eBGP
```

| Node | AS | Router ID | IPv4 prefix | IPv6 prefix |
|------|----|-----------|-------------|-------------|
| r1 | 65001 | 1.1.1.1 | 10.1.0.0/24 | 2001:db8:1::/64 |
| r2 | 65002 | 2.2.2.2 | 10.2.0.0/24 | 2001:db8:2::/64 |
| r3 | 65002 | 3.3.3.3 | 10.3.0.0/24 | 2001:db8:3::/64 |
| r4 | 65003 | 4.4.4.4 | 10.4.0.0/24 | 2001:db8:4::/64 |

Each prefix sits on the router's loopback (`10.N.0.1/24`, `2001:db8:N::1/64`).
Every pair of routers has two sessions, one over IPv4 and one over IPv6.

| Link | Node | Interface | IPv4 address | IPv6 address |
|------|------|-----------|--------------|--------------|
| r1–r2 | r1 | eth1 | 10.0.12.1/24 | 2001:db8:12::1/64 |
| r1–r2 | r2 | eth1 | 10.0.12.2/24 | 2001:db8:12::2/64 |
| r2–r3 | r2 | eth2 | 10.0.23.1/24 | 2001:db8:23::1/64 |
| r2–r3 | r3 | eth1 | 10.0.23.2/24 | 2001:db8:23::2/64 |
| r3–r4 | r3 | eth2 | 10.0.34.1/24 | 2001:db8:34::1/64 |
| r3–r4 | r4 | eth1 | 10.0.34.2/24 | 2001:db8:34::2/64 |

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

Allow about 10 seconds for the sessions to establish.

## Verify

```bash
sudo podman exec clab-bgp-r2 vtysh -c "show bgp summary"
sudo podman exec clab-bgp-r4 vtysh -c "show bgp ipv4 unicast"
sudo podman exec clab-bgp-r4 vtysh -c "show bgp ipv6 unicast"
sudo podman exec clab-bgp-r1 ping -c 3 -I 10.1.0.1 10.4.0.1
sudo podman exec clab-bgp-r1 ping -6 -c 3 -I 2001:db8:1::1 2001:db8:4::1
```

Expected: all four of r2's sessions `Established`, four prefixes per family on
r4 (r1's with AS path `65002 65001`), and 3 ping replies per family.

Replace `sudo podman` with `docker` if you use Docker.

## Try a session shutdown

Shut down only the IPv4 session between r2 and r1:

```bash
sudo podman exec clab-bgp-r2 vtysh \
  -c "configure terminal" \
  -c "router bgp 65002" \
  -c "neighbor 10.0.12.1 shutdown"
sudo podman exec clab-bgp-r4 vtysh -c "show bgp ipv4 unicast"
sudo podman exec clab-bgp-r4 vtysh -c "show bgp ipv6 unicast"
sudo podman exec clab-bgp-r2 vtysh \
  -c "configure terminal" \
  -c "router bgp 65002" \
  -c "no neighbor 10.0.12.1 shutdown"
```

r4 loses 10.1.0.0/24 while the session is down, but keeps 2001:db8:1::/64,
because the IPv6 session is unaffected. Both come back after the shutdown is
removed.

## Teardown

```bash
sudo containerlab destroy -t topology.clab.yml --cleanup
```
