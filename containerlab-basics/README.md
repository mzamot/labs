# Containerlab basics

Three FRR routers in a line, connected with static IPv4 routes.
Blog post: *Containerlab: a network lab on your own machine*.

```
 r1 ──────── r2 ──────── r3
 lo 10.255.0.1/32            lo 10.255.0.3/32
        10.0.12.0/24   10.0.23.0/24
```

| Node | Interface | IPv4 address | Connected to |
|------|-----------|--------------|--------------|
| r1 | eth1 | 10.0.12.1/24 | r2 |
| r1 | lo | 10.255.0.1/32 | — |
| r2 | eth1 | 10.0.12.2/24 | r1 |
| r2 | eth2 | 10.0.23.1/24 | r3 |
| r3 | eth1 | 10.0.23.2/24 | r2 |
| r3 | lo | 10.255.0.3/32 | — |

## Requirements

- The shared lab environment listed in the [root README](../README.md#tested-with)

## Deploy

```bash
sudo containerlab --runtime podman deploy -t topology.clab.yml
```

## Verify

r1 pings r3's loopback, crossing r2:

```bash
sudo podman exec clab-hello-r1 ping -c 3 10.255.0.3
```

Expected: 3 packets received, `ttl=63` (one router crossed).
## Teardown

```bash
sudo containerlab --runtime podman destroy -t topology.clab.yml --cleanup
```
