#!/bin/sh

export K3S_KUBECONFIG_MODE="644"
export INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --flannel-iface=eth1"

TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"

# Install K3s in server (controller) mode
wget -qO- https://get.k3s.io | sh -s -

while [ ! -f $TOKEN_FILE ]; do
	echo "Waiting for k3s token..."
	sleep 2
done

cat $TOKEN_FILE > /vagrant/node-token

while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
	echo "Waiting for k3s kubeconfig..."
	sleep 2
done

sed 's/127.0.0.1/192.168.56.110/g' /etc/rancher/k3s/k3s.yaml > /vagrant/k3s.yaml
