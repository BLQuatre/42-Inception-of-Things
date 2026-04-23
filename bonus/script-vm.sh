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
sudo apt install ca-certificates curl git -y
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

info "Deploying GitLab..."
sudo kubectl apply -f gitlab.yml
ok "GitLab deployment created."

info "Waiting for all ArgoCD pods to be ready (timeout: 300s)..."
sudo kubectl wait --for=condition=Ready --timeout=300s pod --all -n argocd
ok "ArgoCD is fully up and running."

info "Configuring ArgoCD insecure mode (rootpath: /argocd)..."
sudo kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data": {"server.insecure": "true", "server.rootpath": "/argocd"}}'
sudo kubectl rollout restart deployment/argocd-server -n argocd
sudo kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
ok "ArgoCD configured."

info "Applying Ingress..."
sudo kubectl apply -f ingress.yml
ok "Ingress applied."

GITLAB_BOOT_TIMEOUT=3600
GITLAB_PASSWORD_TIMEOUT=900

info "Waiting for GitLab to respond at http://localhost/gitlab/ (timeout: ${GITLAB_BOOT_TIMEOUT}s)..."
response="000"
elapsed=0
while [[ "$elapsed" -lt "$GITLAB_BOOT_TIMEOUT" ]]; do
	response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/gitlab/ || echo "000")
	if [[ "$response" == "200" || "$response" == "301" || "$response" == "302" ]]; then
		break
	fi
	sleep 5
	elapsed=$((elapsed + 5))
	if (( elapsed % 60 == 0 )); then
		info "GitLab not ready yet (${elapsed}s elapsed, last HTTP code: ${response})..."
	fi
done

if [[ "$response" != "200" && "$response" != "301" && "$response" != "302" ]]; then
	err "GitLab did not become reachable before timeout (${GITLAB_BOOT_TIMEOUT}s)."
	exit 1
fi
ok "GitLab endpoint is responding (HTTP ${response})."

info "Waiting for initial GitLab root password (timeout: ${GITLAB_PASSWORD_TIMEOUT}s)..."
password=""
elapsed=0
while [[ -z "$password" && "$elapsed" -lt "$GITLAB_PASSWORD_TIMEOUT" ]]; do
	pod=$(sudo kubectl get pods -n gitlab -l app=gitlab -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
	if [[ -n "$pod" ]]; then
		password=$(sudo kubectl exec -n gitlab "$pod" -- awk '/Password:/ {print $2}' /etc/gitlab/initial_root_password 2>/dev/null || true)
	fi
	if [[ -z "$password" ]]; then
		sleep 2
		elapsed=$((elapsed + 2))
	fi
done

if [[ -z "$password" ]]; then
	err "Timed out waiting for GitLab root password file."
	exit 1
fi

echo "$password" > .gitlab_password
ok "GitLab root password captured."

REPO_NAME="IoT-project-lomont"
GITHUB_USERNAME="MiniKlar"
GITLAB_URL="http://localhost/gitlab"
GITHUB_REPO_URL="https://github.com/$GITHUB_USERNAME/$REPO_NAME"

get_gitlab_access_token() {
	curl_response=$(curl --silent --show-error --request POST \
		--form "grant_type=password" \
		--form "username=root" \
		--form "password=$(cat .gitlab_password)" \
		"$GITLAB_URL/oauth/token")
	access_token=$(echo "$curl_response" | grep -o '"access_token":"[^"]*' | cut -d':' -f2 | tr -d '"')
	if [[ -z "$access_token" ]]; then
		err "Failed to get GitLab access token. Response: $curl_response"
		return 1
	fi
	echo "$access_token"
}

create_gitlab_repo() {
	local access_token="$1"
	http_code=$(curl --silent --show-error --request POST \
		--header "Authorization: Bearer $access_token" \
		--form "name=$REPO_NAME" \
		--form "visibility=public" \
		"$GITLAB_URL/api/v4/projects" \
		-o /dev/null \
		-w "%{http_code}")
	if [[ "$http_code" != "201" && "$http_code" != "400" && "$http_code" != "409" ]]; then
		err "Failed to create GitLab repo '$REPO_NAME' (HTTP $http_code)."
		return 1
	fi
}

info "Cloning GitHub repo '$REPO_NAME'..."
rm -rf /tmp/"$REPO_NAME"
git clone "$GITHUB_REPO_URL" /tmp/"$REPO_NAME"

access_token=$(get_gitlab_access_token) || exit 1

info "Creating GitLab repo '$REPO_NAME'..."
create_gitlab_repo "$access_token" || exit 1

cd /tmp/"$REPO_NAME"
git remote add gitlab "http://oauth2:$access_token@localhost/gitlab/root/$REPO_NAME.git"

info "Pushing repo to local GitLab..."
current_branch=$(git rev-parse --abbrev-ref HEAD)
git push --set-upstream gitlab "$current_branch"
cd - > /dev/null

info "Creating ArgoCD app 'webapp' (pointing to local GitLab)..."
sudo kubectl apply -f dev_app.yml
ok "ArgoCD app 'webapp' created."

ARGOCD_PASSWORD=$(sudo kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)
echo ""
echo "ArgoCD UI: http://localhost/argocd"
echo "Username:  admin"
echo "Password:  ${ARGOCD_PASSWORD}"
echo ""
echo "GitLab UI: http://localhost/gitlab"
echo "Username:  root"
echo "Password:  ${password}"
