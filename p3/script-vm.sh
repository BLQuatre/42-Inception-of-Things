#!/bin/bash

sh scripts/install.sh

sudo k3d cluster create lomontS -p "80:80"

sh scripts/argocd.sh

sh scripts/dev.sh

ARGOCD_PASSWORD=$(cat .argocd_password)

echo ""
echo "ArgoCD UI: http://localhost/argocd"
echo "Username:  admin"
echo "Password:  ${ARGOCD_PASSWORD}"
echo ""
echo "Webapp UI: http://localhost"
