# Releasing to Cloudron

Versions are semver. CloudronManifest.json `version` is the single source of truth:
the app reads it at boot (`EaHelper::VERSION`, shown on the about page and footer),
and Cloudron compares manifest versions to detect updates. The git tag must match it.

## Release

Needs Cloudron CLI 9+, where `cloudron builder` builds the image on the server's
Container Registry app and pushes it there. Always pass `--server`, before the
subcommand: the CLI's default server may be another Cloudron. Logins use the Cloudron
username and an App password (Account > App Passwords), not the account password.

### First time

Before you do this:
- set the variables below
- Ensure the Cloudron can pull from the registry: System > Docker with registry auth
- Bump version in CloudronManifest.json to match VER below via PR and merge to main
- Start in the repo root, on main

```bash
# Variables
VER=0.1.0
SERVER=my.<your-domain>
REGI=registry.<your-domain>
DEST=appointments.<your-domain>

# One-time per machine
cloudron login $SERVER
cloudron --server $SERVER builder login $REGI

git tag v$VER && git push origin v$VER
# Build on the server and push to the registry; --repository is needed on the first build
cloudron --server $SERVER builder build --repository $REGI/openappointments --tag $VER

cloudron --server $SERVER install --location $DEST --last-build
```

#### Subsequent releases

We keep a deploy script with our real values outside this repo; it runs these steps
and refuses a version that does not match CloudronManifest.json.

```bash
git tag v$VER && git push origin v$VER
cloudron --server $SERVER builder build --repository $REGI/openappointments --tag $VER
cloudron --server $SERVER update --app $DEST --last-build
```

### Alternatively you can build it on your machine instead of on the server

```bash
docker login $REGI
docker build -t $REGI/openappointments:$VER .
docker push $REGI/openappointments:$VER
cloudron --server $SERVER update --app $DEST --image $REGI/openappointments:$VER
```

## Rails console

To get a Rails console on a running cloudron instance run:

```bash
cloudron exec -t --app appointments.openouthair.com -- bash -c 'set -a; source /app/data/env; cd /app/code; HOME=/tmp exec bin/rails console'
```

## Crash report emails

Production emails unhandled exceptions to the addresses in the `EXCEPTION_RECIPIENTS`
environment variable (comma separated). Unset, no crash reports are sent. Set it on
the instance with the Cloudron CLI; the app restarts to pick it up:

```bash
cloudron env set --app appointments.<your-domain> EXCEPTION_RECIPIENTS=you@example.org
cloudron env list --app appointments.<your-domain>
```

## Update safety

- The old container is stopped before the new one starts; SQLite is single-writer, so
  `bin/rails db:prepare` in start.sh applies migrations safely on boot.
- Keep migrations additive within a minor version. Destructive changes (drop/rename)
  go in two releases: release N stops using the column, release N+1 drops it.
- All persistent state is under /app/data (SQLite files in /app/data/db, Active Storage
  in /app/data/storage, SECRET_KEY_BASE in /app/data/env), covered by Cloudron backups.

## First install

start.sh runs `openappointments:install` once: seeds roles/settings and creates the
administrator account. The generated password is printed in the app logs
(`cloudron logs --app <domain>`); change it after first login.
