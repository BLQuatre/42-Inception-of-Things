RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok() { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${CYAN}[-->]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1"; }

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
sudo k3d cluster create lomontS -p "443:443@loadbalancer" -p "80:80@loadbalancer"
ok "k3d cluster created."

info "Applying namespaces..."
sudo kubectl apply -f namespaces.yml
ok "Namespaces applied."

info "Installing ArgoCD..."
sudo kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
ok "ArgoCD installed."

info "Creating ArgoCD app 'gitlab'..."
sudo kubectl apply -f gitlab.yml
ok "ArgoCD app 'gitlab' created."

info "Waiting for all ArgoCD pods to be ready (timeout: 300s)..."
sudo kubectl wait --for=condition=Ready --timeout=300s pod --all -n argocd
ok "ArgoCD is fully up and running."

info "Configuring ArgoCD insecure mode and NodePort 30080..."
sudo kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data": {"server.insecure": "true", "server.rootpath": "/argocd"}}'
sudo kubectl rollout restart deployment/argocd-server -n argocd
sudo kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
ok "ArgoCD configured."

info "Applying Ingress for ArgoCD..."
sudo kubectl apply -f ingress.yml
ok "Ingress applied."

response="000"
while [[ "$response" != "302" ]]; do
	response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/gitlab/ || echo "000")
	[[ "$response" != "302" ]] && sleep 1
done

REPO_NAME="IoT-project-lomont"
GITHUB_USERNAME="MiniKlar"
GITLAB_URL="http://localhost/gitlab"
GITHUB_REPO_URL="https://github.com/$GITHUB_USERNAME/$REPO_NAME"
CURRENT_DIR=$(pwd)

get_gitlab_access_token() {
	curl_response=$(curl --silent --show-error --request POST \
		--form "grant_type=password" \
		--form "username=root" \
		--form "password=$(cat .gitlab_password)" \
		"$GITLAB_URL/oauth/token")
	echo "$curl_response" | grep -o '"access_token":"[^"]*' | cut -d':' -f2 | tr -d '"'
}

create_gitlab_repo() {
	local access_token="$1"
	curl --silent --show-error --request POST \
		--header "Authorization: Bearer $access_token" \
		--form "name=$REPO_NAME" \
		--form "visibility=public" \
		"$GITLAB_URL/api/v4/projects" > /dev/null
}

clone_github_repo() {
	rm -rf /tmp/"$REPO_NAME"
	git clone "$GITHUB_REPO_URL" /tmp/"$REPO_NAME"
}

printf "${GREEN}[DEV]${NC} - Cloning GitHub repo...\n"
clone_github_repo

access_token=$(get_gitlab_access_token)

printf "${GREEN}[DEV]${NC} - Creating GitLab repo '$REPO_NAME'...\n"
create_gitlab_repo "$access_token"

cd /tmp/"$REPO_NAME"
git remote add gitlab "http://oauth2:$access_token@localhost/gitlab/root/$REPO_NAME.git"

printf "${GREEN}[DEV]${NC} - Pushing repo to local GitLab...\n"
git push --set-upstream gitlab master
cd "$CURRENT_DIR"

info "Creating ArgoCD app 'webapp'..."
sudo kubectl apply -f dev_app.yml -n argocd
ok "ArgoCD app 'webapp' created."

pod=$(sudo kubectl get pods -n gitlab -l app=gitlab -o jsonpath='{.items[0].metadata.name}')
password=$(sudo kubectl exec -n gitlab "$pod" -- cat /etc/gitlab/initial_root_password | awk '/Password:/ {print $2}')
echo "$password" > .gitlab_password

ARGOCD_PASSWORD=$(sudo kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)
echo ""
echo "ArgoCD UI: http://localhost/argocd"
echo "Username:	admin"
echo "Password:	${ARGOCD_PASSWORD}"
echo ""
echo "GitLab UI: http://localhost/gitlab"
echo "Username:	root"
echo "Password:	${password}"
