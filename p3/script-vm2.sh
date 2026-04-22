RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${CYAN}[-->]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; }

# install docker
info "Updating apt and installing prerequisites..."
sudo apt update
sudo apt install ca-certificates curl -y
ok "Prerequisites installed."

info "Setting up Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
. /etc/os-release
sudo curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
ok "Docker GPG key configured."

info "Adding Docker apt repository..."
# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/${ID}
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
ok "Docker repository added."

info "Updating apt with Docker repository..."
sudo apt update
ok "Apt updated."

info "Installing Docker..."
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
ok "Docker installed."

info "Downloading kubectl..."
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
ok "kubectl installed."

info "Installing k3d..."
sudo curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
ok "k3d installed."

info "Creating k3d cluster 'mycluster'..."
sudo k3d cluster create mycluster -p "80:80@loadbalancer" -p "443:443@loadbalancer"
ok "k3d cluster created."

info "Applying namespaces and ingress..."
sudo kubectl apply -f namespace_argo.yaml
sudo kubectl apply -f namespace_dev.yaml
sudo kubectl apply -f ingress.yaml
ok "Namespaces and ingress applied."

info "Downloading ArgoCD CLI..."
sudo curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
sudo rm argocd-linux-amd64
ok "ArgoCD CLI installed."

info "Installing ArgoCD manifests..."
sudo kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
ok "ArgoCD manifests applied."

info "Waiting for argocd-server deployment to become available (timeout: 300s)..."
sudo kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
ok "argocd-server is available."

info "Patching argocd-server service to ClusterIP..."
sudo kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}'
ok "argocd-server service patched."

info "Setting kubectl context namespace to argocd..."
sudo kubectl config set-context --current --namespace=argocd
ok "Context namespace set."

info "Retrieving ArgoCD initial admin password..."
ARGOCD_PASSWORD=$(sudo argocd admin initial-password -n argocd | head -1)
ok "Password retrieved."

info "Starting port-forward to argocd-server..."
sudo kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PF_PID=$!
sleep 3
ok "Port-forward started (PID: ${PF_PID})."

info "Logging in to ArgoCD..."
argocd login localhost:8080 --username admin --password ${ARGOCD_PASSWORD} --insecure
ok "Logged in to ArgoCD."

info "Creating ArgoCD app 'webapp'..."
argocd app create webapp --server localhost:8080 --insecure --repo https://github.com/MiniKlar/IoT-project.git --path . --dest-server https://kubernetes.default.svc --dest-namespace dev
ok "ArgoCD app 'webapp' created."

info "Syncing ArgoCD app 'webapp'..."
argocd app sync webapp --server localhost:8080 --insecure
ok "ArgoCD app 'webapp' synced."

kill ${PF_PID} 2>/dev/null


