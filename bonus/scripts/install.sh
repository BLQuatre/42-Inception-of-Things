#!/bin/bash
# This script install ca-certificates, Docker, kubectl, and k3d

sudo apt update
sudo apt install ca-certificates curl git -y

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo rm get-docker.sh

sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
sudo rm kubectl

sudo curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
