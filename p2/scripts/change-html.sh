#!/bin/sh

# On boucle sur tous les pods de chaque application pour modifier leur index.html
# en y insérant le nom du pod. Cela permet de voir quel replica répond.

for app in app-one app-two app-three; do
	kubectl wait --for=condition=ready pod -l app=$app --timeout=300s
	for pod in $(kubectl get pods -l app=$app -o name); do
		kubectl exec $pod -- sh -c "echo '<h1>Hello from POD: $pod</h1>' > /usr/share/nginx/html/index.html"
	done
done
