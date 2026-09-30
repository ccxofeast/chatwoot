# Chatwoot Local-Image Deployment

This is the direct local-image release path for the VibeCraft Chatwoot instance
on `192.168.116.123`.

The server never builds the application image. The complete flow is:

`Windows Docker build` -> `docker save` -> `SCP image tar` -> `server docker load` ->
`recreate rails/sidekiq` -> `health check`

PostgreSQL, Redis, volumes, runtime secrets, and the source tree stay on the
server. Only the immutable application image and this README are transferred.

## Fast path

Run this from the repository root on Windows. The default path transfers an
uncompressed Docker tar because the test server is on the local network and the
image compresses by only a few percent. This avoids local gzip time and remote
decompression time.

```powershell
powershell -ExecutionPolicy Bypass -File .\ops\chatwoot\deploy-local.ps1
```

Use gzip only on a slow or metered link:

```powershell
powershell -ExecutionPolicy Bypass -File .\ops\chatwoot\deploy-local.ps1 -Compress
```

Use a full rebuild only when the Docker cache is suspect:

```powershell
powershell -ExecutionPolicy Bypass -File .\ops\chatwoot\deploy-local.ps1 -NoCache
```

The default SSH key is `%USERPROFILE%\.ssh\id_ed25519_vm100`. Override it when
needed:

```powershell
powershell -ExecutionPolicy Bypass -File .\ops\chatwoot\deploy-local.ps1 `
  -SshKey "$env:USERPROFILE\.ssh\id_ed25519_vm100"
```

## What the script changes

1. Builds an immutable local tag in `vibecraft/chatwoot` using the current Git
   revision and UTC timestamp.
2. Saves the image as a temporary Docker tar archive and transfers it to the
   server. `-Compress` changes this to `chatwoot.tar.gz` for low-bandwidth links.
3. Backs up `/opt/chatwoot/docker-compose.production.yaml`.
4. Loads the image and updates only the Chatwoot application image reference.
5. Recreates `rails` and `sidekiq`; PostgreSQL, Redis, and all volumes stay up.
6. Installs this README at `/opt/chatwoot/README.md` and removes the temporary
   transfer directory.

The script prints separate timings for build, packaging, transfer, server
rollout, and total time. The server rollout also prints `docker load`, container
recreate, and health-check timings.

The server does not need Docker Hub credentials, Infisical, Node, Ruby, or the
source tree. Runtime secrets remain in `/etc/chatwoot/chatwoot.env` and are
never copied to the workstation or committed to Git.

## Server checks

```bash
cd /opt/chatwoot
docker-compose --env-file /etc/chatwoot/chatwoot.env \
  -f docker-compose.production.yaml ps
curl --fail http://127.0.0.1:3000/health
docker logs --tail=100 chatwoot-rails-1
docker logs --tail=100 chatwoot-sidekiq-1
```

The public URL is served through the existing reverse proxy or tunnel. A
successful local `/health` response and running `rails`/`sidekiq` containers are
the deployment gate.

## Why a release can be slow

The Dockerfile intentionally keeps the dependency layers before `COPY . /app`.
Gem and pnpm installation should therefore be cached. A source change still
invalidates the production asset layer, which recompiles the widget and
dashboard with Vite. That build is expected to take about one to two minutes on
the local workstation.

Do not use `-NoCache` for routine UI releases and do not prune Docker builder
cache. A cold build reinstalls Ruby and JavaScript dependencies and may pull base
images, which is the usual cause of a release taking 15-30 minutes.

The image is roughly 747MB and compresses to roughly 708MB, so gzip saves little
on the local network. The default uncompressed path is faster overall. If a
release is still slow, use the printed timings to identify whether the delay is
local asset compilation, image packaging, network transfer, server `docker
load`, container startup, or health readiness.

## Rollback

The deploy script restores the previous Compose file automatically if the
health check fails. For a manual rollback, choose the matching backup and
recreate the two application services:

```bash
cd /opt/chatwoot
cp docker-compose.production.yaml.bak-<timestamp> \
  docker-compose.production.yaml
docker-compose --env-file /etc/chatwoot/chatwoot.env \
  -f docker-compose.production.yaml up -d rails sidekiq
```

Do not run `down -v`, remove the PostgreSQL/Redis containers, or delete the
named volumes during a UI-only release.
