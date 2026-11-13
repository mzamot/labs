#!/bin/sh
# Builds the AlmaLinux VM image for containerlab.
#
# The image is AlmaLinux's official cloud image wrapped with the vrnetlab launcher, which
# boots it in QEMU and wires its network interfaces to containerlab. The launcher's common
# code is fetched from the upstream vrnetlab project at build time.
#
# Run it from this directory. It builds with sudo podman, so the image lands in the storage
# that containerlab uses.
set -e
cd "$(dirname "$0")"

IMAGE=almalinux-10-GenericCloud-latest.qcow2
# The vrnetlab commit this lab was tested with
VRNETLAB_COMMIT=5af59cf917659e3a1b905ea3ffb404c000f83683
TAG=localhost/vrnetlab/almalinux_almalinux:10

bash download.sh

rm -rf build
mkdir build
git clone https://github.com/srl-labs/vrnetlab.git build/vrnetlab
git -C build/vrnetlab checkout --quiet "$VRNETLAB_COMMIT"
cp build/vrnetlab/common/* build/
cp launch.py Containerfile "$IMAGE" build/

sudo podman build --build-arg IMAGE="$IMAGE" -t "$TAG" -f build/Containerfile build/
rm -rf build
echo "Built $TAG"
