# Distributed Systems — Technical Report
**Name / Student ID:** ___
**Cohort:** MSc DE1
**GitHub repository:** ___
**Docker Hub repository:** ___
**Final image tag deployed:** `<dockerhub-username>/msc-de1-flask-app:1.0.0`

> Convert this to PDF before submission. Aim for 4–6 pages; screenshots
> support the explanation, they don't replace it.

## 1. Baseline
- Steps taken to run the original app without Docker (venv, install, `python run.py`).
- Result of testing the 4 documented routes (`/`, `/items`, `/items/{id}`, `POST /items`).
- Result of `python -m unittest discover tests` — include the pass count.
- Note the undeclared `flask_testing` import in `tests/__init__.py` (unused,
  missing from `requirements.txt`) and why it doesn't affect the documented
  test command.
- [Screenshot: baseline tests passing]
- [Screenshot: curl output for each route]

## 2. Dockerization
- Key Dockerfile choices: base image (`python:3.12-slim`), layer ordering
  (requirements before source) for cache efficiency, non-root user, exec-form
  CMD via gunicorn, HEALTHCHECK using the stdlib (no extra packages).
- Why gunicorn was added as a dependency change.
- Final image size (`docker images`) and layer breakdown (`docker history`).
- [Screenshot: docker build success]
- [Screenshot: docker images / docker history output]

## 3. Security
- Non-root execution: how it's enforced in the image (`USER appuser`) and
  proven at runtime (`docker exec ... whoami`).
- Vulnerability scan: tool + version, image tag scanned, findings by
  severity, what changed as a result, any remaining HIGH/CRITICAL and why.
- SBOM: tool used, format (SPDX/CycloneDX), where stored.
- [Paste or summarize security/vulnerability-scan.txt]
- [Reference security/sbom.spdx.json]

## 4. Docker Hub
- Repository URL, tags published (`1.0.0`, `latest`), and the pull/run/verify steps.
- [Screenshot: docker push]
- [Screenshot: pulled image running + curl proof]

## 5. Kubernetes
- Cluster architecture: kind, 1 control-plane + 2 workers.
- Objects deployed: Namespace, Deployment (replicas, probes, resources,
  security context), Service, NetworkPolicy, ConfigMap/Secret template.
- [Screenshot: kubectl get nodes]
- [Screenshot: kubectl get pods -o wide, kubectl get svc]

## 6. Distributed behavior
- **Self-healing:** pod deleted, replacement created automatically —
  explain desired-state reconciliation via the ReplicaSet controller.
- **Scaling:** 2 → 3 → 2 replicas, with `kubectl get pods` evidence at each step.
- **Rolling update:** new image tag deployed, `rollout status` / `rollout history` output.
- **Rollback:** `rollout undo`, confirm previous version restored.
- [Screenshots for each of the four demonstrations]

## 7. Conclusion
- What you learned about the difference between a Docker container and a
  Kubernetes-managed application (replication, desired state, health
  checking, self-healing, service abstraction, controlled updates).
- One concrete improvement you'd make for an actual production deployment
  (e.g. Ingress + TLS, HPA, a policy-enforcing CNI, external secrets
  manager, persistent storage if the item list needed to survive restarts).
