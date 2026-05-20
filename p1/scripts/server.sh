#!/bin/sh

export K3S_KUBECONFIG_MODE="644"
export INSTALL_K3S_EXEC="server --node-external-ip=192.168.56.110 --bind-address=192.168.56.110 --flannel-iface=eth1"
wget -qO- https://get.k3s.io | sh -

while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
	sleep 1
	echo "Waiting for token file..."
done

cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token
