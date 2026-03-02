#!/usr/bin/env bash
set -euo pipefail

echo "deleting SonarQube resources"
kubectl delete -f k8s/sonarqube/ingress.yaml --ignore-not-found
kubectl delete -f k8s/sonarqube/sonarqube.yaml --ignore-not-found
kubectl delete -f k8s/sonarqube/postgres.yaml --ignore-not-found
kubectl delete -f k8s/sonarqube/postgres-secret.yaml --ignore-not-found
kubectl delete -f k8s/sonarqube/namespace.yaml --ignore-not-found
