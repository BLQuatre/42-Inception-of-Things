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

info "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo rm get-docker.sh
ok "Docker installed."

info "Downloading kubectl..."
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
sudo rm kubectl
ok "kubectl installed."

info "Installing k3d..."
sudo curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
ok "k3d installed."

info "Creating k3d cluster 'lomontS'..."
sudo k3d cluster create lomontS -p "8888:8888@loadbalancer" -p "443:443@loadbalancer" -p "80:80@loadbalancer"
ok "k3d cluster created."

info "Applying namespaces..."
sudo kubectl apply -f namespaces.yml
ok "Namespaces applied."

info "Installing ArgoCD..."
sudo kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
ok "ArgoCD installed."

info "Waiting for all ArgoCD pods to be ready (timeout: 300s)..."
sudo kubectl wait --for=condition=Ready --timeout=300s pod --all -n argocd
ok "ArgoCD is fully up and running."

info "Configuring ArgoCD insecure mode and NodePort 30080..."
sudo kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data": {"server.insecure": "true"}}'
sudo kubectl rollout restart deployment/argocd-server -n argocd
sudo kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
ok "ArgoCD configured."

info "Applying Ingress for ArgoCD..."
sudo kubectl apply -f ingress.yml
ok "Ingress applied."

info "Creating ArgoCD app 'webapp'..."
sudo kubectl apply -f app.yaml
ok "ArgoCD app 'webapp' created."

info "Deploying GitLab CE in namespace 'gitlab'..."
sudo kubectl apply -f gitlab.yml
ok "GitLab manifests applied."

info "Adding gitlab.local to /etc/hosts..."
grep -qxF "127.0.0.1 gitlab.local" /etc/hosts || echo "127.0.0.1 gitlab.local" | sudo tee -a /etc/hosts > /dev/null
ok "gitlab.local mapped to 127.0.0.1."

info "Waiting for GitLab pod to be ready (timeout: 600s) — GitLab takes a few minutes to initialize..."
sudo kubectl wait --for=condition=Ready --timeout=600s pod --all -n gitlab
ok "GitLab is up and running."

ARGOCD_PASSWORD=$(sudo kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)
echo ""
echo "ArgoCD UI: http://localhost:8080"
echo "Username:  admin"
echo "Password:  ${ARGOCD_PASSWORD}"
echo ""
echo "GitLab UI: http://gitlab.local"
echo "Username:  root"
echo "Password:  (set on first login via the web UI)"
