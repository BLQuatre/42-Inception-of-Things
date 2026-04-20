#!/bin/sh

export K3S_KUBECONFIG_MODE="644"
export K3S_TOKEN="vagrant-k3s-secret-token-12345"
export INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --flannel-iface=eth1"

# Install K3s in server (controller) mode
wget -qO- https://get.k3s.io | sh -s -
