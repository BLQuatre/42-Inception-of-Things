#!/bin/sh

# On boucle sur tous les pods de chaque application pour modifier leur index.html
# en y insérant le nom du pod. Cela permet de voir quel replica répond.

# Application 1
for pod in $(sudo kubectl get pods -l app=app-one -o name); do
    kubectl exec $pod -- sh -c "echo '<h1>Hello from POD: $pod</h1>' > /usr/share/nginx/html/index.html"
done

# Application 2
for pod in $(sudo kubectl get pods -l app=app-two -o name); do
    kubectl exec $pod -- sh -c "echo '<h1>Hello from POD: $pod</h1>' > /usr/share/nginx/html/index.html"
done

# Application 3
for pod in $(sudo kubectl get pods -l app=app-three -o name); do
    kubectl exec $pod -- sh -c "echo '<h1>Hello from POD: $pod</h1>' > /usr/share/nginx/html/index.html"
done