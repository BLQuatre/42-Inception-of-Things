#!/bin/sh

export K3S_TOKEN_FILE="/vagrant/node-token"
export K3S_URL="https://192.168.56.110:6443"
export INSTALL_K3S_EXEC="--flannel-iface=eth1"
wget -qO- https://get.k3s.io | sh -

rm -f /vagrant/node-token
