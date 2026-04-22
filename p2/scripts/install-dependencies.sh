#!/bin/sh

#install curl
apk add curl

#install k3s
curl -sfL https://get.k3s.io | sh -

#move to the correct folder
cd /mnt

#Applying app one configuration
sudo kubectl apply -f app-one-deployment.yaml
sudo kubectl apply -f app-one-service.yaml

#Applying app two configuration
sudo kubectl apply -f app-two-deployment.yaml
sudo kubectl apply -f app-two-service.yaml

#Applying app three configuration
sudo kubectl apply -f app-three-deployment.yaml
sudo kubectl apply -f app-three-service.yaml

# #running all three applications
# sudo kubectl run app-one
# sudo kubectl run app-two
# sudo kubectl run app-three
