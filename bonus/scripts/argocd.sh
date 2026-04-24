#!/bin/bash

sudo kubectl apply -f ./confs/argocd/namespace.yml
sudo kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

sudo kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data": {"server.insecure": "true"}}'

until sudo kubectl get pods -n argocd --field-selector=status.phase=Running 2>/dev/null | grep -q "argocd"; do
	sleep 3
done

sudo kubectl apply -n argocd -f ./confs/argocd/ingress.yml

ARGOCD_PASSWORD=$(sudo kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)
echo $ARGOCD_PASSWORD > .argocd_password
