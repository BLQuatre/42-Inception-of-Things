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
sudo k3d cluster create mycluster -p "80:80@loadbalancer" -p "443:443@loadbalancer" -p "8080:30080@server:0"
ok "k3d cluster created."

info "Applying namespaces..."
sudo kubectl apply -f namespace_argo.yaml
sudo kubectl apply -f namespace_dev.yaml
ok "Namespaces applied."

info "Installing ArgoCD manifests..."
sudo kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
ok "ArgoCD manifests applied."

info "Waiting for argocd-server deployment to become available (timeout: 300s)..."
sudo kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
ok "argocd-server is available."

info "Waiting for argocd-repo-server deployment to become available (timeout: 300s)..."
sudo kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
ok "argocd-repo-server is available."

info "Configuring ArgoCD insecure mode and NodePort 30080..."
sudo kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data": {"server.insecure": "true"}}'
sudo kubectl patch svc argocd-server -n argocd --type='json' -p='[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"add","path":"/spec/ports/0/nodePort","value":30080}]'
sudo kubectl rollout restart deployment/argocd-server -n argocd
sudo kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
ok "ArgoCD configured."

info "Setting kubectl context namespace to argocd..."
sudo kubectl config set-context --current --namespace=argocd
ok "Context namespace set."

info "Creating ArgoCD app 'webapp'..."
sudo kubectl apply -f app.yaml
ok "ArgoCD app 'webapp' created."

ARGOCD_PASSWORD=$(sudo kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)
echo ""
echo "ArgoCD UI: http://localhost:8080"
echo "Username:  admin"
echo "Password:  ${ARGOCD_PASSWORD}"
