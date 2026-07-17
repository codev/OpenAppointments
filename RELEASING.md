# Releasing to Cloudron

Versions are semver and must match in two places: the git tag and CloudronManifest.json
`version`. Cloudron compares manifest versions to detect updates.

## Release

### First time

Before you do this:
- set the variables below
- Ensure Cloudron config is correct - System -> Docker with registry auth
- Bump version in CloudronManifest.json to match VER below via PR and merge to main
- Start in the repo root

```bash
# Variables
VER=0.1.0
REGI=registry.<your-domain>
BUILD=build.<your-domain>
DEST=appointments.<your-domain>

# One-time per machine: prompts for a build service access token
cloudron build --build-service-url $BUILD login

git tag v$VER && git push origin v$VER
# Build on server and push to registry; the repository is stored for future builds
cloudron build --tag $VER --repository $REGI/openappointments

cloudron install --image $REGI/openappointments:$VER \
  --location $DEST
```

#### Subsequent releases

A git-ignored `deploy.sh` in the repo root holds our real values for these steps.

```bash
# Variables
VER=1.0.0
REGI=registry.<your-domain>
DEST=appointments.<your-domain>

git tag v$VER && git push origin v$VER
cloudron build --tag $VER # Build on server and push to registry

cloudron update --app $DEST --image $REGI/openappointments:$VER
```

### Alternatively you can build it on your machine instead of a build server

```bash
docker build -t $REGI/openappointments:$VER .
docker login $REGI
docker push $REGI/openappointments:$VER

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
