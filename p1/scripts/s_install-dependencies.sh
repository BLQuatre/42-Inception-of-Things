#!/bin/sh

# OpenRC is require for K3s
apk add openrc

# Install K3s in server (controller) mode
wget -qO- https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s -

# Install Kubectl
wget -q https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
kubectl version --client