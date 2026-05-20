#!/bin/bash

sudo kubectl apply -f ./confs/dev/namespace.yml
sudo kubectl apply -n argocd -f ./confs/dev/app.yml
sudo kubectl apply -n dev -f ./confs/dev/ingress.yml
