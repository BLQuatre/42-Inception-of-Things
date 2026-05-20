#!/bin/sh

export K3S_KUBECONFIG_MODE="644"
export INSTALL_K3S_EXEC="server"
wget -qO- https://get.k3s.io | sh -

until kubectl get nodes 2>/dev/null | grep -q ' Ready '; do
	echo "Waiting for k3s node to be Ready..."
	sleep 5
done

kubectl apply -f /vagrant/confs/app1-deployment.yml
kubectl apply -f /vagrant/confs/app1-service.yml

kubectl apply -f /vagrant/confs/app2-deployment.yml
kubectl apply -f /vagrant/confs/app2-service.yml

kubectl apply -f /vagrant/confs/app3-deployment.yml
kubectl apply -f /vagrant/confs/app3-service.yml

kubectl apply -f /vagrant/confs/ingress-config.yml
