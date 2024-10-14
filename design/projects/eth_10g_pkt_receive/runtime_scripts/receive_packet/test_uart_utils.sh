#!/usr/bin/env bash
#socat -d -d pty,raw,echo=0 pty,raw,echo=0
sudo ip link set enp8s0d1 up
sudo ip addr add 192.168.0.1 dev enp8s0d1
sudo ip route add 192.168.0.0/16 via 192.168.0.1

echo "Can access 192.168.0.0/16 via 192.168.0.1 (enp8s0d1)"
