#!/bin/bash

sudo kubectl apply -f ./confs/gitlab/namespace.yml
sudo kubectl apply -n gitlab -f ./confs/gitlab/volume.yml
sudo kubectl apply -n gitlab -f ./confs/gitlab/deployment.yml
sudo kubectl apply -n gitlab -f ./confs/gitlab/service.yml

seconds=0
until sudo kubectl get pods -n gitlab --field-selector=status.phase=Running 2>/dev/null | grep -q "gitlab"; do
	echo "Waiting for GitLab to be ready... ($seconds seconds)"
	sleep 3
	((seconds+=3))
done
until sudo kubectl get pods -n gitlab --field-selector=status.phase=Running 2>/dev/null | grep -q "gitlab"; do
	echo "Waiting for GitLab to be ready..."
	sleep 3
done

sudo kubectl apply -n gitlab -f ./confs/gitlab/ingress.yml

seconds=0
until [[ $(curl -s -o /dev/null -w "%{http_code}" http://localhost/gitlab/) == "302" ]]; do
	echo "Waiting for GitLab to be accessible... ($seconds seconds)"
	sleep 3
	((seconds+=3))
done

GITLAB_PASSWORD=$(sudo kubectl exec -n gitlab $(sudo kubectl get pods -n gitlab -l app=gitlab -o jsonpath='{.items[0].metadata.name}') -- cat /etc/gitlab/initial_root_password | awk '/Password:/ {print $2}')
echo "$GITLAB_PASSWORD" > .gitlab_password
