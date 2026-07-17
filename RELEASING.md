# Releasing to Cloudron

Versions are semver and must match in two places: the git tag and CloudronManifest.json
`version`. Cloudron compares manifest versions to detect updates.

## Release

```bash
# 1. Bump version in CloudronManifest.json, commit via PR.
# 2. Tag and push.
git tag v0.1.0
git push origin v0.1.0

# 3. Build and push the image (from the repo root).
REGI=registry.<your-domain>
docker build -f Dockerfile.cloudron -t $REGI/openappointments:0.1.0 .
docker login $REGI
docker push $REGI/openappointments:0.1.0

# 4. First install / update.
cloudron install --image $REGI/openappointments:0.1.0 --location appointments
cloudron update --app appointments.openouthair.com --image $REGI/openappointments:0.1.0
```

`cloudron build` can replace the docker build/push pair if a build service is configured.

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
