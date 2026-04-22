# install docker
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
. /etc/os-release
sudo curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/${ID}
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

sudo curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

sudo k3d cluster create mycluster -p "80:80@loadbalancer" -p "443:443@loadbalancer"

sudo kubectl apply -f namespace_argo.yaml
sudo kubectl apply -f namespace_dev.yaml
sudo kubectl apply -f ingress.yaml

#download argocd CLI

sudo curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
sudo rm argocd-linux-amd64

sudo kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}'

sudo kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

sudo kubectl config set-context --current --namespace=argocd

sudo argocd admin initial-password -n argocd

ARGOCD_PASSWORD=$(sudo argocd admin initial-password -n argocd | head -1)

argocd login localhost:80 --username admin --password ${ARGOCD_PASSWORD} --insecure

argocd app create webapp --repo https://github.com/MiniKlar/IoT-project.git --path . --dest-server https://kubernetes.default.svc --dest-namespace dev

argocd app sync webapp


