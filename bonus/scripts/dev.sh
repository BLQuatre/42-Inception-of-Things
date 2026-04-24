#!/bin/bash

REPO_NAME="red-tetris-kyaubry"
GITHUB_USERNAME="KylianAUBRY"
GITLAB_URL="http://localhost/gitlab"
CURRENT_DIR=$(pwd)

rm -rf /tmp/"$REPO_NAME"
git clone "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git" /tmp/"$REPO_NAME"

curl_response=$(curl --silent --show-error --request POST \
	--form "grant_type=password" --form "username=root" \
	--form "password=$(cat .gitlab_password)" "$GITLAB_URL/oauth/token")

access_token=$(echo "$curl_response" | grep -o '"access_token":"[^"]*' | cut -d':' -f2 | tr -d '"')
echo "Gitlab access token: $access_token"

curl --silent --show-error --request POST \
	--header "Authorization: Bearer $access_token" --form "name=$REPO_NAME" \
	--form "visibility=public" "$GITLAB_URL/api/v4/projects"

cd /tmp/"$REPO_NAME"
gitlab_repo_url_with_token="http://oauth2:$access_token@localhost/gitlab/root/$REPO_NAME.git"
git remote add gitlab "$gitlab_repo_url_with_token"

git push --set-upstream gitlab master
cd "$CURRENT_DIR"

sudo kubectl apply -f ./confs/dev/namespace.yml
sudo kubectl apply -n argocd -f ./confs/dev/app.yml
sudo kubectl apply -n dev -f ./confs/dev/ingress.yml
