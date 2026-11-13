# Containerlab basics

Three FRR routers in a line, connected with static IPv4 routes.
Blog post: *Containerlab: a network lab on your own machine*.

```
 r1 ──────── r2 ──────── r3
 lo 10.255.0.1/32            lo 10.255.0.3/32
        10.0.12.0/24   10.0.23.0/24
```

| Node | eth1 | eth2 | lo |
|------|------|------|----|
| r1 | 10.0.12.1/24 | – | 10.255.0.1/32 |
| r2 | 10.0.12.2/24 | 10.0.23.1/24 | – |
| r3 | 10.0.23.2/24 | – | 10.255.0.3/32 |

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

## Verify

r1 pings r3's loopback, crossing r2:

```bash
sudo podman exec clab-hello-r1 ping -c 3 10.255.0.3
```

Expected: 3 packets received, `ttl=63` (one router crossed).
Replace `sudo podman` with `docker` if you use Docker.

## Teardown

```bash
sudo containerlab destroy -t topology.clab.yml --cleanup
```
