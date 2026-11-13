# SRv6 L3VPN basics

Two provider edge routers (PE1, PE2) run FRR and carry two customers, red and blue, across a plain IPv6 router (P). BGP distributes each customer's routes together with an SRv6 service SID, and the PEs forward customer traffic through SRv6 tunnels. Both customers use the same two subnets.
Blog post: *L3VPN over SRv6: separate customer networks on one backbone*.

```
 red-a  ┐                                  ┌  red-b
        ├── PE1 ────────── P ────────── PE2 ┤
 blue-a ┘                                  └  blue-b
```

| Node | Interface | Address | Connected to |
|------|-----------|---------|--------------|
| pe1 | eth1 | 2001:db8:1::1/64 | p |
| pe1 | eth2 (VRF red) | 192.168.1.1/24 | red-a |
| pe1 | eth3 (VRF blue) | 192.168.1.1/24 | blue-a |
| pe1 | lo | fc00:0:1::1/128 | — |
| p | eth1 | 2001:db8:1::2/64 | pe1 |
| p | eth2 | 2001:db8:2::1/64 | pe2 |
| pe2 | eth1 | 2001:db8:2::2/64 | p |
| pe2 | eth2 (VRF red) | 192.168.2.1/24 | red-b |
| pe2 | eth3 (VRF blue) | 192.168.2.1/24 | blue-b |
| pe2 | lo | fc00:0:2::1/128 | — |
| red-a | eth1 | 192.168.1.2/24 | pe1 |
| blue-a | eth1 | 192.168.1.2/24 | pe1 |
| red-b | eth1 | 192.168.2.2/24 | pe2 |
| blue-b | eth1 | 192.168.2.2/24 | pe2 |

| Customer | Site A subnet (PE1) | Site B subnet (PE2) | Route distinguisher and route target |
|----------|---------------------|---------------------|--------------------------------------|
| red | 192.168.1.0/24 | 192.168.2.0/24 | 65000:10 |
| blue | 192.168.1.0/24 | 192.168.2.0/24 | 65000:20 |

## Requirements

- The shared lab environment listed in the [root README](../README.md#tested-with)
- SRv6 and VRF support in the host kernel, including the `End.DT46` behavior. A recent kernel is needed.
- The VRF kernel module loaded on the host: `sudo modprobe vrf`. Containers can't load modules,
  and the `net.vrf.strict_mode` setting the PEs need only exists once it is loaded.

The PEs use the official FRR image (`quay.io/frrouting/frr:10.7.1`). The P router and the
customer hosts use a small image built from the official Alpine image with `iproute2` and
`tcpdump` (see `image/Containerfile`). Build it once:

```bash
sudo podman build -t localhost/l3vpn-node:latest image/
```

## Deploy

```bash
sudo containerlab --runtime podman deploy -t topology.clab.yml
```

Allow about 10 seconds for the BGP session to establish.

## Verify

```bash
sudo podman exec clab-l3vpn-pe1 vtysh -c "show bgp ipv4 vpn summary"
sudo podman exec clab-l3vpn-pe1 vtysh -c "show ip route vrf red"
sudo podman exec clab-l3vpn-pe2 ip -6 route show | grep seg6
sudo podman exec clab-l3vpn-red-a ping -c 2 192.168.2.2
sudo podman exec clab-l3vpn-blue-a ping -c 2 192.168.2.2
```

Expected: one BGP neighbor with two prefixes, a `B>` route in each VRF with a `seg6` SID, two
`End.DT46` SIDs on pe2, and both pings succeed.

## Watch the tunnel

Capture on the P router while red-a pings red-b. The outer destination is PE2's SID for the red VRF:

```bash
sudo podman exec clab-l3vpn-p tcpdump -nn -i eth1 -v ip6
sudo podman exec clab-l3vpn-red-a ping -c 1 192.168.2.2
```

## Teardown

```bash
sudo containerlab --runtime podman destroy -t topology.clab.yml --cleanup
```
