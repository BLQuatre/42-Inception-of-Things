#!/bin/bash

sudo kubectl apply -f ./confs/gitlab/namespace.yml
sudo kubectl apply -n gitlab -f ./confs/gitlab/volume.yml
sudo kubectl apply -n gitlab -f ./confs/gitlab/deployment.yml
sudo kubectl apply -n gitlab -f ./confs/gitlab/service.yml

until sudo kubectl get pods -n gitlab --field-selector=status.phase=Running 2>/dev/null | grep -q "gitlab"; do
	sleep 3
done

sudo kubectl apply -n gitlab -f ./confs/gitlab/ingress.yml

until [[ $(curl -s -o /dev/null -w "%{http_code}" http://localhost/gitlab/) == "302" ]]; do
	sleep 3
done

GITLAB_PASSWORD=$(sudo kubectl exec -n gitlab $(sudo kubectl get pods -n gitlab -l app=gitlab -o jsonpath='{.items[0].metadata.name}') -- cat /etc/gitlab/initial_root_password | awk '/Password:/ {print $2}')
echo "$GITLAB_PASSWORD" > .gitlab_password
