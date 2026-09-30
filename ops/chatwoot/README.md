# Chatwoot Fast Local Deployment

This directory documents the direct local-image release path for the VibeCraft
Chatwoot instance on `192.168.116.123`.

## Fast path

Run this from the repository root on Windows. The command builds a Linux amd64
image, copies it to the server, updates only the `rails` and `sidekiq` services,
and checks `/health` for up to three minutes before returning.

```powershell
powershell -ExecutionPolicy Bypass -File .\ops\chatwoot\deploy-local.ps1
```

Use a full rebuild when the Docker cache is suspect:

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
2. Saves the image as a temporary tar archive and transfers it to the server.
3. Backs up `/opt/chatwoot/docker-compose.production.yaml`.
4. Loads the image and updates only the Chatwoot application image reference.
5. Recreates `rails` and `sidekiq`; PostgreSQL, Redis, and all volumes stay up.
6. Installs this README at `/opt/chatwoot/README.md` and removes the temporary
   transfer directory.

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
