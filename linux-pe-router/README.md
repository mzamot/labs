# Moving the PE onto the server

Linux servers that each act as their own provider edge (PE) router. Inside every server,
namespaces separate the roles: the server's own stack, a layer 2 service (VXLAN with EVPN and
an anycast gateway), a software PE (IS-IS, BGP L3VPN and SRv6), and a workloads namespace that
owns routed service prefixes. An FRR spine provides the backbone and reflects the VPN routes.

Blog post: *Moving the PE onto the server: SRv6, EVPN and VXLAN on a Linux host*.

```
                         spine (FRR: IS-IS, VPN route reflector)
          ┌───────────────┬───────┴───────┬───────────────┐
        node1           node2           node3           node4    ← AlmaLinux VMs
```

node1 to node3 become PEs at deployment. node4 is cabled to the spine's spare port, which is
already configured, and joins later without any change to the spine or the other servers.

Every address comes from the server's number N (1 to 9):

| Namespace | Interface | Address | Role |
|-----------|-----------|---------|------|
| default | ve-host-br | 10.10.100.1N/24 | The server's stack on the stretched LAN |
| default | ve-host-infra | 10.20.N.2/30 | The server's routed link into `infra` |
| l2-vxlan | vlan100 | 10.10.100.(1+N)/24, so .2 to .10 | The gateway's own per-node interface on VLAN 100 |
| l2-vxlan | vlan100-gw | 10.10.100.1/24, MAC 02:00:00:00:01:00 | Anycast gateway, identical on every server |
| l2-vxlan | ve-vtep-infra | 10.20.N.6/30 | The VTEP address |
| workloads | ve-wl-infra | 10.20.N.10/30 | The workloads end of the routed handoff |
| pe-router | ve-infra-host, ve-infra-vtep, ve-infra-wl | 10.20.N.1, .5, .9 | The PE's ends of the three links, in VRF `infra` |
| pe-router | ext-test | 192.0.2.N/32 | A test address in VRF `external` |
| pe-router | lo | fc00:0:N::1/128 | Loopback, inside the SRv6 locator fc00:0:N::/48 |
| pe-router | eth1 | IPv6 link-local, MTU 9000 | Fabric link to the spine |

| VRF | Table | RD | Route target | Exports |
|-----|-------|----|--------------|---------|
| infra | 10 | N.N.N.N:10 | 65000:10 | 10.20.0.0/16 (up to /30), 10.10.100.0/24, 10.250.0.0/16 (up to /24) |
| external | 20 | N.N.N.N:20 | 65000:20 | 192.0.2.0/24 |

BGP AS 65000 carries the VPN routes: each PE peers with the spine, which accepts any PE
loopback in `fc00:0::/32` (`bgp listen range`). AS 65001 carries EVPN: node1's and node2's
VTEPs are two route reflectors with separate cluster IDs, each accepting any VTEP in
`10.20.0.0/16` and peering with the other; every other VTEP peers only with the two of them.
The EVPN sessions run through the `infra` VRF.

## Files

| File | Purpose |
|------|---------|
| `topology.clab.yml` | The spine and four VMs |
| `configs/pe.sh` | Turns a VM into PE number N: namespaces, links, sysctls, FRR containers |
| `configs/addresses.sh` | Derives every per-node address from N; `check-addresses.sh` verifies them for N = 1 to 9 |
| `configs/router.conf.in` | FRR template for the software PE (IS-IS, VPN, SRv6, export policy) |
| `configs/l2-rr.conf.in` | FRR template for node1's and node2's VTEPs, the EVPN route reflectors |
| `configs/l2.conf.in` | FRR template for every other VTEP, a client of both reflectors |
| `configs/spine/frr.conf` | The spine: IS-IS on four ports, VPN route reflector |
| `vm/` | Builds the AlmaLinux VM image for containerlab |

## Requirements

- The shared environment from the [root README](../README.md#tested-with), plus KVM, `git`
  and `curl`. The four VMs need 2 vCPUs and 2 GB of RAM each.
- The AlmaLinux VM image. `vm/` builds it from AlmaLinux's official cloud image and the
  vrnetlab launcher (`launch.py`), which boots the VM in QEMU and connects its interfaces to
  containerlab. The build fetches vrnetlab's shared `common` code from the upstream project,
  pinned to a tested commit, and runs `sudo podman build`:

```bash
sh vm/build.sh
```

This produces `localhost/vrnetlab/almalinux_almalinux:10`. The topology sets `QEMU_MEMORY: 2048`
and `QEMU_SMP: 2` for each VM. The VMs install podman and pull the official FRR image
(`quay.io/frrouting/frr:10.7.1`) themselves, so they need internet access.

The VMs run AlmaLinux 10.2 (kernel 6.12).

## Deploy

```bash
sudo containerlab --runtime podman deploy -t topology.clab.yml
```

The VMs take about two minutes to boot. Then provision the first three. The VM user is `clab`
and the password is `clab@123`:

```bash
for n in 1 2 3; do
  scp -r configs clab@clab-pe-on-host-node$n:~/
  ssh clab@clab-pe-on-host-node$n "cd configs && sudo sh pe.sh $n"
done
```

Each run takes under a minute. Give the sessions another 30 seconds. `pe.sh` builds from
scratch; to start over, destroy and redeploy.

## Verify

From the machine running containerlab:

```bash
sudo podman exec clab-pe-on-host-spine vtysh -c "show isis neighbor"
sudo podman exec clab-pe-on-host-spine vtysh -c "show bgp ipv4 vpn summary"
```

On node1 (`ssh clab@clab-pe-on-host-node1`):

```bash
sudo podman exec frr-pe-router vtysh -c "show ip route vrf infra"
sudo podman exec frr-l2-vxlan vtysh -c "show bgp l2vpn evpn summary"
ping -c 2 10.20.2.2                        # routed link to node2's server
ping -c 2 10.10.100.12                     # stretched LAN to node2's server
ping -c 2 -M do -s 1472 10.10.100.12       # a full 1500-byte packet
```

Expected: three IS-IS neighbors and three dynamic VPN peers on the spine; on node1 and node2,
the other reflector plus node3 as a dynamic EVPN client; BGP routes with `seg6` SIDs in `infra`;
and all pings succeed.

## Add a service

On node1, create a workload network and give the PE a route to it:

```bash
sudo ip -n workloads link add svc0 type dummy
sudo ip -n workloads addr add 10.250.1.10/24 dev svc0
sudo ip -n workloads link set svc0 up
sudo ip -n pe-router route add 10.250.1.0/24 via 10.20.1.10 vrf infra
```

From node2's server, which reaches the service range through the anycast gateway:

```bash
ping -c 2 10.250.1.10
```

Prefixes outside `10.250.0.0/16` are not exported. Remove the route to withdraw the service:

```bash
sudo ip -n pe-router route del 10.250.1.0/24 vrf infra
```

## Add a PE

```bash
scp -r configs clab@clab-pe-on-host-node4:~/
ssh clab@clab-pe-on-host-node4 "cd configs && sudo sh pe.sh 4"
```

The spine and the other servers need no change: the spine port is already configured, and the
VPN reflector and both EVPN reflectors accept the new peer dynamically.

## Watch the packets

On node1, capture on the fabric link (outgoing SRv6 packets of 160 bytes or more, which skips
the EVPN sessions' keepalives and ARP inside VXLAN), then ping in a second terminal:

```bash
sudo ip netns exec pe-router tcpdump -nn -v -i eth1 \
  'ip6 proto 43 and src fc00:0:1::1 and greater 160'
ping -c 1 10.20.2.2        # SRv6 directly around the server's packet
ping -c 1 10.10.100.12     # SRv6 around VXLAN around the server's frame
```

## Teardown

```bash
sudo containerlab --runtime podman destroy -t topology.clab.yml --cleanup
```
