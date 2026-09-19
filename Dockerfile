# syntax=docker/dockerfile:1

# ---- Base image -------------------------------------------------------
# Small, official, well-maintained Python image (slim variant = fewer
# packages, smaller attack surface, smaller size vs the full python image).
FROM python:3.12-slim AS runtime

# Keep Python from writing .pyc files / buffering stdout, which makes
# `docker logs` behave correctly (unbuffered logs, no stale bytecode).
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Clear WORKDIR for everything that follows.
WORKDIR /app

# ---- Dependencies first (layer caching) --------------------------------
# Copying only the dependency file before the source means this layer is
# only rebuilt when requirements.txt actually changes.
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt \
    # Remove apt lists / caches so no build leftovers end up in the image.
    && rm -rf /root/.cache

# ---- Non-root user ------------------------------------------------------
# Create a dedicated, unprivileged user/group to run the app as.
RUN groupadd --gid 10001 appgroup \
    && useradd --uid 10001 --gid appgroup --shell /usr/sbin/nologin --no-create-home appuser

# ---- Application source (only what's needed at runtime) -----------------
COPY app/ ./app/
COPY run.py .

# Make sure the non-root user owns the app directory (needed for a
# read-only root filesystem + writable /tmp only, see compose/k8s config).
RUN chown -R appuser:appgroup /app

USER appuser

# Only the port the app actually listens on.
EXPOSE 5000

# Docker-level health check: hit the root route with the stdlib so we
# don't need to add curl/wget (keeps the image minimal).
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request,sys; sys.exit(0) if urllib.request.urlopen('http://127.0.0.1:5000/', timeout=2).status == 200 else sys.exit(1)"]

# Exec form: runs as PID 1 directly (no shell), so SIGTERM from
# `docker stop` / Kubernetes reaches gunicorn correctly for graceful
# shutdown instead of being swallowed by a shell wrapper.
ENTRYPOINT ["gunicorn"]
CMD ["--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "2", "--timeout", "30", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
