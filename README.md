# Labs

Hands-on networking labs for the posts on
[opencloud.io](https://www.opencloud.io). Each directory is a
complete lab with its own README, topology and configs.

| Lab | Description |
|-----|-------------|
| [containerlab-basics](containerlab-basics) | Three FRR routers, deployed and tested with containerlab |
| [isis-basics](isis-basics) | Four FRR routers running IS-IS: adjacencies, metrics and link failover |
| [bgp-basics](bgp-basics) | Four FRR routers running BGP: eBGP, iBGP, AS paths and next hops |
| [vxlan-basics](vxlan-basics) | Three VTEPs stretching a layer 2 segment over a routed network |
| [evpn-basics](evpn-basics) | Three FRR VTEPs using BGP EVPN to discover each other and share MAC addresses |
| [namespaces-vrf-basics](namespaces-vrf-basics) | Separating routing on a Linux host with VRFs, network namespaces and veth pairs |
| [srv6-basics](srv6-basics) | Four Linux routers forwarding with SRv6: segment lists, End and End.DX4 behaviors, and uSID |
| [srv6-l3vpn-basics](srv6-l3vpn-basics) | Two FRR PEs carrying two customers over SRv6 with BGP L3VPN |
| [linux-pe-router](linux-pe-router) | Linux VMs, each its own PE router: SRv6 L3VPN, EVPN/VXLAN, an anycast gateway, dynamic service prefixes, redundant EVPN route reflectors, and a fourth PE that joins without changes elsewhere |

## Tested with

Every lab runs on the same environment, set up as described in the
[containerlab post](https://www.opencloud.io/writing/containerlab-network-lab/):

| Component | Version |
|-----------|---------|
| Host | Debian 13, kernel 7.2 (bare metal or a VM) |
| containerlab | 0.83.0 |
| podman | 5.4, with the API socket enabled (`sudo systemctl enable --now podman.socket`) |
| FRR image | `quay.io/frrouting/frr:10.7.1` |
| Alpine image | `docker.io/library/alpine:latest`, for labs that build their own node image |

All commands use `sudo containerlab --runtime podman ...`. Deploy from a lab's directory with
`sudo containerlab --runtime podman deploy -t topology.clab.yml`, and remove it with
`sudo containerlab --runtime podman destroy -t topology.clab.yml --cleanup`.

## Extra requirements per lab

Only the differences from the shared environment above. Each lab's README has the details.

| Lab | Needs in addition |
|-----|-------------------|
| vxlan-basics, evpn-basics | The `vxlan` kernel module; a small Alpine image built from `image/Containerfile` |
| namespaces-vrf-basics | The `vrf` kernel module; an Alpine image built from `image/Containerfile` |
| srv6-basics | SRv6 support in the kernel; for the uSID part, a recent kernel and iproute2 (tested with iproute2 7.0); an Alpine image built from `image/Containerfile` |
| srv6-l3vpn-basics | SRv6 and VRF support in the kernel, with the `vrf` module loaded on the host (`sudo modprobe vrf`) before deploying; an Alpine image built from `image/Containerfile` |
| linux-pe-router | KVM, and room for four VMs with 2 vCPUs and 2 GB of RAM each; the AlmaLinux VM image built with `vm/build.sh` (needs `git` and `curl`); internet access from the VMs. The VMs run AlmaLinux 10.2 (kernel 6.12) |
