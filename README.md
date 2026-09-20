# MSc DE1 — Distributed Systems: Docker & Local Kubernetes Project

## 1. Objective and architecture overview

This repository containerizes, secures, publishes and orchestrates the
[UBC Flask Sample App](https://github.com/ubc/flask-sample-app) — a small
Flask REST API for managing an in-memory list of items (`/`, `/items`,
`/items/{id}`).

Architecture at a glance:

```
 Developer machine
 ┌───────────────────────────────────────────────────────────┐
 │  docker build → local image → docker run / docker compose  │
 │        │                                                    │
 │        ▼                                                    │
 │  docker push → Docker Hub (<dockerhub-username>/msc-de1-flask-app) │
 │        │                                                    │
 │        ▼                                                    │
 │  kind cluster (1 control-plane + 2 workers)                 │
 │    namespace: msc-de1-project                                │
 │      Deployment (2+ replicas, probes, non-root, limits)      │
 │      Service (ClusterIP) ── kubectl port-forward ── you      │
 │      NetworkPolicy (documents intended access)               │
 └───────────────────────────────────────────────────────────┘
```

## 2. Starter application

Original source: https://github.com/ubc/flask-sample-app

## 3. Prerequisites

- Python 3.11+ and `venv`
- Docker Desktop (or Docker Engine + Compose plugin)
- [kind](https://kind.sigs.k8s.io/) and `kubectl`
- [Trivy](https://aquasecurity.github.io/trivy/) or Docker Scout (vulnerability scan)
- [Syft](https://github.com/anchore/syft) or Docker Scout (SBOM)
- A Docker Hub account

## 4. Run the original application locally (baseline)

```bash
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
python run.py                   # serves on http://127.0.0.1:5000
```

In another terminal, verify the documented routes:

```bash
curl http://127.0.0.1:5000/
curl http://127.0.0.1:5000/items
curl -X POST http://127.0.0.1:5000/items -H "Content-Type: application/json" -d '{"name":"item1"}'
curl http://127.0.0.1:5000/items/0
```

Run the existing unit tests exactly as the README documents:

```bash
python -m unittest discover tests
```

**Baseline result:** all 4 tests pass and all 4 routes behave as documented.
Note (documented, not fixed, to preserve the original app): `tests/__init__.py`
imports `flask_testing`, which is **not** listed in `requirements.txt` and is
otherwise unused. `python -m unittest discover tests` still passes, but
running the same tests with `pytest` fails at collection time with
`ModuleNotFoundError: No module named 'flask_testing'`. Use the documented
`unittest discover` command.

**Dependency change:** `gunicorn` was added to `requirements.txt`. It is not
needed to run the app directly with `python run.py`, but it replaces the
Flask development server as the production WSGI server used inside the
container (see Dockerfile `CMD`).

## 5. Build and run the Docker image

```bash
docker build -t msc-de1-flask-app:local .
docker run -d --name msc-de1-flask-app -p 5000:5000 msc-de1-flask-app:local

curl http://127.0.0.1:5000/
docker logs msc-de1-flask-app
docker inspect --format='{{json .State.Health}}' msc-de1-flask-app
docker exec msc-de1-flask-app whoami          # should print: appuser (not root)

docker stop msc-de1-flask-app
docker rm msc-de1-flask-app
```

Image inspection evidence to capture for the report:

```bash
docker images msc-de1-flask-app:local          # final image size
docker history msc-de1-flask-app:local         # layers
docker inspect msc-de1-flask-app:local --format='{{.Config.ExposedPorts}}'
docker inspect msc-de1-flask-app:local --format='{{.Config.User}}'
```

## 6. Run with Docker Compose

```bash
docker compose up --build -d
curl http://127.0.0.1:5000/
docker compose ps
docker compose logs -f
docker compose down
```

## 7. Vulnerability scan and SBOM

```bash
trivy image --severity LOW,MEDIUM,HIGH,CRITICAL msc-de1-flask-app:local \
  > security/vulnerability-scan.txt

syft msc-de1-flask-app:local -o spdx-json=security/sbom.spdx.json
```

See `security/` for the placeholder files describing exactly what to
produce and how to summarize it in the report.

## 8. Publish to Docker Hub

```bash
docker login
docker tag msc-de1-flask-app:local <dockerhub-username>/msc-de1-flask-app:1.0.0
docker tag msc-de1-flask-app:local <dockerhub-username>/msc-de1-flask-app:latest
docker push <dockerhub-username>/msc-de1-flask-app:1.0.0
docker push <dockerhub-username>/msc-de1-flask-app:latest

# Verify by pulling fresh and running it
docker rmi msc-de1-flask-app:local
docker pull <dockerhub-username>/msc-de1-flask-app:1.0.0
docker run -d --name pulled-check -p 5000:5000 <dockerhub-username>/msc-de1-flask-app:1.0.0
curl http://127.0.0.1:5000/
docker rm -f pulled-check
```

**Public Docker Hub repository:** `https://hub.docker.com/r/mohan1008/msc-de1-flask-app`
**Image used for the Kubernetes deployment below:** `<dockerhub-username>/msc-de1-flask-app:1.0.0`

## 9. Create the kind cluster

```bash
kind create cluster --config kind/kind-config.yaml
kubectl get nodes -o wide   # 1 control-plane + 2 workers, all Ready
```

## 10. Deploy to Kubernetes

Before applying, edit `k8s/deployment.yaml` and replace
`<dockerhub-username>/msc-de1-flask-app:1.0.0` with your actual published
image.

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/optional-config-or-secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/network-policy.yaml

kubectl -n msc-de1-project get pods -o wide
kubectl -n msc-de1-project get deployment flask-app
kubectl -n msc-de1-project get svc flask-app
```

## 11. Access and test the application

```bash
kubectl -n msc-de1-project port-forward svc/flask-app 8000:80
# in another terminal:
curl http://127.0.0.1:8000/
curl http://127.0.0.1:8000/items
```

## 12. Distributed systems demonstrations

**A. Replication and service discovery**
```bash
kubectl -n msc-de1-project get pods -o wide
kubectl -n msc-de1-project get endpoints flask-app
```

**B. Self-healing**
```bash
kubectl -n msc-de1-project get pods
kubectl -n msc-de1-project delete pod <one-pod-name>
kubectl -n msc-de1-project get pods -w   # a replacement pod appears automatically
```

**C. Scaling**
```bash
kubectl -n msc-de1-project scale deployment flask-app --replicas=3
kubectl -n msc-de1-project get pods
kubectl -n msc-de1-project scale deployment flask-app --replicas=2
```

**D. Rolling update and rollback**
```bash
# after publishing a new image tag, e.g. 1.0.1
kubectl -n msc-de1-project set image deployment/flask-app \
  flask-app=<dockerhub-username>/msc-de1-flask-app:1.0.1
kubectl -n msc-de1-project rollout status deployment/flask-app
kubectl -n msc-de1-project rollout history deployment/flask-app

# rollback
kubectl -n msc-de1-project rollout undo deployment/flask-app
kubectl -n msc-de1-project rollout status deployment/flask-app
```

## 13. Delete / clean up the local cluster

```bash
kubectl delete namespace msc-de1-project
kind delete cluster --name msc-de1-cluster
docker compose down --volumes
```

## 14. Security decisions and known limitations

- The container runs as a dedicated non-root user (`appuser`, uid 10001)
  in both the Docker image and the Kubernetes `securityContext`.
- `readOnlyRootFilesystem: true` is used in both Compose and Kubernetes;
  the only writable path is a mounted `/tmp` (`tmpfs` in Compose, `emptyDir`
  in Kubernetes), since gunicorn needs a small writable scratch area even
  though the app itself holds no state on disk.
- All Linux capabilities are dropped (`cap_drop: ALL` / `capabilities.drop: [ALL]`);
  `allowPrivilegeEscalation: false` and `seccompProfile: RuntimeDefault` are set.
- No `privileged: true`, no Docker-socket mount, no host networking, no
  hostPath volumes, and no host PID/IPC namespace sharing anywhere in this repo.
- **NetworkPolicy limitation:** kind's default CNI (kindnet) does not
  enforce `NetworkPolicy` objects. `k8s/network-policy.yaml` documents the
  intended access (only same-namespace traffic on port 5000, plus DNS
  egress) but is not actually enforced unless the cluster is created with
  a policy-capable CNI such as Calico or Cilium.
- CPU/memory `requests` and `limits` are set on the container so a single
  replica cannot consume unbounded cluster resources.
- No secrets are required by the application as shipped. `k8s/optional-config-or-secret.yaml`
  includes a documented Secret **template** with a placeholder value only —
  no real secret is committed to this repository.
