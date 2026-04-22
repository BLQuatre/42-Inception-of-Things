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
ok "Docker installed."

info "Downloading kubectl..."
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
ok "kubectl installed."

info "Installing k3d..."
sudo curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
ok "k3d installed."

info "Creating k3d cluster 'lomontS'..."
sudo k3d cluster create lomontS -p "80:80@loadbalancer" -p "443:443@loadbalancer" -p "8080:30080@server:0"
ok "k3d cluster created."

info "Installing ArgoCD manifests..."
sudo kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
ok "ArgoCD manifests applied."

info "Applying namespaces..."
sudo kubectl apply -f namespace_argo.yaml
sudo kubectl apply -f namespace_dev.yaml
ok "Namespaces applied."

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

info "Creating ArgoCD app 'webapp'..."
sudo kubectl apply -f app.yaml
ok "ArgoCD app 'webapp' created."

ARGOCD_PASSWORD=$(sudo kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)
echo ""
echo "ArgoCD UI: http://localhost:8080"
echo "Username:  admin"
echo "Password:  ${ARGOCD_PASSWORD}"
