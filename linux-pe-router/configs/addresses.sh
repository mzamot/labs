# Per-node addresses for PE number N. Sourced by pe.sh and check-addresses.sh.
#
# Stretched LAN, 10.10.100.0/24:
#   .1          anycast gateway (the same on every node)
#   .2 - .10    each gateway's own address (vlan100), node 1 to 9
#   .11 - .19   the server's own stack, node 1 to 9
# infra VRF: each node owns 10.20.N.0/24.

node_addresses() {
  case "$1" in
    [1-9]) N=$1 ;;
    *) echo "node number must be a single digit from 1 to 9, got '$1'" >&2; return 1 ;;
  esac
  PE_L3=10.20.$N.1                    # the PE end of the server's routed link
  HOST_L3=10.20.$N.2                  # the server's routed link into infra
  VTEP_GW=10.20.$N.5                  # the PE end of the VTEP's link
  VTEP=10.20.$N.6                     # the VTEP address
  WL_PE=10.20.$N.9                    # the PE end of the workloads handoff
  WL=10.20.$N.10                      # the workloads end
  SVI=10.10.100.$((1 + N))            # this node's own gateway address: .2 to .10
  MACHINE=10.10.100.$((10 + N))       # the server's stack on the stretched LAN: .11 to .19
}
