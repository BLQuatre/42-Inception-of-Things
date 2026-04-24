#!/bin/sh

#install curl
apk add curl

#install k3s
curl -sfL https://get.k3s.io | sh -

#sleeping to wait k3s to be operationnal
#sleep 20

#move to the correct folder
cd /mnt

#Applying app one configuration
kubectl apply -f app-one-deployment.yaml
kubectl apply -f app-one-service.yaml

#Applying app two configuration
kubectl apply -f app-two-deployment.yaml
kubectl apply -f app-two-service.yaml

#Applying app three configuration
kubectl apply -f app-three-deployment.yaml
kubectl apply -f app-three-service.yaml

#Applying ingress configuration
kubectl apply -f ingress-config.yaml

#sh /mnt/scripts/change-html.sh