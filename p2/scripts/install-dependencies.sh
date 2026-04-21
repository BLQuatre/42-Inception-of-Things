#!/bin/sh

#install curl
apk add curl



#install k3s
curl -sfL https://get.k3s.io | sh -

#Applying app one configuration
kubectl apply -f app-one-deployment.yaml
kubectl apply -f app-one-service.yaml

#Applying app two configuration
kubectl apply -f app-two-deployment.yaml
kubectl apply -f app-two-service.yaml

#Applying app three configuration
kubectl apply -f app-three-deployment.yaml
kubectl apply -f app-three-service.yaml

#running all three applications
kubectl run app-one
kubectl run app-two
kubectl run app-three
