# Namespaces and VRF basics

One Linux router, two customers with the same address plan. The router keeps their routes apart with VRFs, then uses a network namespace and a veth pair to show the stronger form of isolation.
Blog post: *Network namespaces and VRFs: separate routing on one Linux host*.

```
   red1 ────── router ────── blue1
  10.0.0.2    eth1  eth2     10.0.0.2
```

| Node | Interface | IPv4 address | Connected to |
|------|-----------|--------------|--------------|
| router | eth1 | — | red1 |
| router | eth2 | — | blue1 |
| red1 | eth1 | 10.0.0.2/24 | router |
| blue1 | eth1 | 10.0.0.2/24 | router |

Both clients use the same address on purpose. The router's addresses are added during the walkthrough in the post.

## Requirements

- The shared lab environment listed in the [root README](../README.md#tested-with)
- The `vrf` kernel module available on the host

The nodes use a small image built from the official Alpine image with `iproute2`
(see `image/Containerfile`). Build it once:

```bash
sudo podman build -t localhost/nsvrf-node:latest image/
```

## Deploy

```bash
sudo containerlab --runtime podman deploy -t topology.clab.yml
```

## Verify

Open a shell on the router and create two VRFs, one per customer, with the same address on each:

```bash
sudo podman exec -it clab-nsvrf-router sh
```

```sh
ip link add red type vrf table 10
ip link add blue type vrf table 20
ip link set red up
ip link set blue up
ip link set eth1 master red
ip link set eth2 master blue
ip addr add 10.0.0.1/24 dev eth1
ip addr add 10.0.0.1/24 dev eth2

ping -c 2 -I red 10.0.0.2
ping -c 2 -I blue 10.0.0.2
ip neigh show vrf red
ip neigh show vrf blue
```

Expected: both pings succeed, and each VRF's neighbor table has `10.0.0.2` with a
different MAC address (red1's and blue1's).

Then a namespace joined by a veth pair:

```sh
ip netns add ns1
ip link add veth0 type veth peer name veth1
ip link set veth1 netns ns1
ip addr add 172.16.0.1/30 dev veth0
ip link set veth0 up
ip -n ns1 addr add 172.16.0.2/30 dev veth1
ip -n ns1 link set veth1 up
ip -n ns1 link set lo up

ping -c 2 172.16.0.2
ip -n ns1 -br link
```

Expected: the ping succeeds, and `ns1` only sees `lo` and `veth1`.

## Teardown

```bash
sudo containerlab --runtime podman destroy -t topology.clab.yml --cleanup
```
