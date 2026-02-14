# Kubernetes

This repo contains a minimal example for running **NGINX** on Kubernetes.

## Quick start (kind + ingress-nginx)

This will:

- Create a local kind cluster (with ports 80/443 mapped to your host)
- Install **ingress-nginx**
- Deploy NGINX (Deployment + Service + Ingress)

```bash
chmod +x scripts/kind-up.sh scripts/kind-down.sh
./scripts/kind-up.sh
```

Access it:

```bash
curl -H 'Host: nginx.local' http://127.0.0.1/
```

If you want the browser-friendly hostname, add this on your host machine:

```text
127.0.0.1 nginx.local
```

Tear down:

```bash
./scripts/kind-down.sh
```

## Prerequisites (local cluster)

You need a Kubernetes cluster and `kubectl` access.

Recommended for local dev on Linux:

1) Install Docker Engine (or Docker Desktop) and make sure Docker is running.
2) Install `kubectl`.
3) Install **kind** (Kubernetes-in-Docker).

Useful links:

- Docker: https://docs.docker.com/engine/install/
- kubectl: https://kubernetes.io/docs/tasks/tools/#kubectl
- kind: https://kind.sigs.k8s.io/docs/user/quick-start/

## Create a local cluster (kind)

```bash
kind create cluster --name demo
kubectl cluster-info
```

To delete later:

```bash
kind delete cluster --name demo
```

## Deploy NGINX

Apply the manifests:

```bash
kubectl apply -f k8s/nginx-deployment.yaml
kubectl apply -f k8s/nginx-service.yaml
kubectl rollout status deployment/nginx
kubectl get pods -l app=nginx
kubectl get svc nginx
```

## Access NGINX

### Option A: Port-forward (works everywhere)

```bash
kubectl port-forward service/nginx 8080:80
```

Then open: http://localhost:8080

### Option B: Ingress (needs an Ingress controller)

This repo includes an example Ingress at [k8s/nginx-ingress.yaml](k8s/nginx-ingress.yaml) using:

- host: `nginx.local`
- ingressClassName: `nginx`

Apply it:

```bash
kubectl apply -f k8s/nginx-ingress.yaml
```

For local clusters (like kind), you must also install an Ingress controller such as **ingress-nginx**.
See: https://kubernetes.github.io/ingress-nginx/deploy/

If you don’t want to set up Ingress, use port-forwarding (Option A).

### Option B: If you’re on Minikube

```bash
minikube service nginx --url
```

## Cleanup

```bash
kubectl delete -f k8s/nginx-ingress.yaml || true
kubectl delete -f k8s/nginx-service.yaml
kubectl delete -f k8s/nginx-deployment.yaml
```