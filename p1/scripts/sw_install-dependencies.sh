#!/bin/sh

export K3S_URL="https://192.168.56.110:6443"
export K3S_TOKEN=$(cat /vagrant/node-token)
export INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=eth1"

# Install K3s in agent mode
wget -qO- https://get.k3s.io | sh -s -

rm /vagrant/node-token
