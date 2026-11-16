#!/bin/sh
# Checks the per-node addresses from addresses.sh for every supported node number:
# each is a valid host address, and no address is used twice on the stretched LAN
# or in the infra VRF.
# Usage: sh check-addresses.sh
DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/addresses.sh"
fail=0
lan="10.10.100.1"                     # the anycast gateway
infra=""

octet_ok() {                          # $1 = address; the last octet must be 1-254
  last=${1##*.}
  [ "$last" -ge 1 ] && [ "$last" -le 254 ]
}

for n in 1 2 3 4 5 6 7 8 9; do
  node_addresses "$n" || { fail=1; continue; }
  printf 'node %s: SVI %-13s server %-13s VTEP %s\n' "$n" "$SVI" "$MACHINE" "$VTEP"
  for a in $SVI $MACHINE $PE_L3 $HOST_L3 $VTEP_GW $VTEP $WL_PE $WL; do
    octet_ok "$a" || { echo "  invalid host address: $a"; fail=1; }
  done
  lan="$lan $SVI $MACHINE"
  infra="$infra $PE_L3 $HOST_L3 $VTEP_GW $VTEP $WL_PE $WL"
done

dups=$(printf '%s\n' $lan $infra | sort | uniq -d)
[ -n "$dups" ] && { echo "duplicate addresses: $dups"; fail=1; }

for bad in 0 10 a ""; do
  if (node_addresses "$bad") 2>/dev/null; then echo "accepted invalid node number '$bad'"; fail=1; fi
done

[ "$fail" = 0 ] && echo "all addresses valid and unique" || { echo "FAILED"; exit 1; }
