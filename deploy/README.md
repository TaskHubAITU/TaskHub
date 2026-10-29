# Deployment runbook

Prerequisites: Linux host with Docker Compose, DNS A/AAAA records pointing to it,
ports 80/443 open, and a Flutter SDK on the build machine. Do not expose port
8000. Caddy terminates HTTPS and overwrites X-Real-IP; trust-proxy mode is safe
only with this private API network.

Build and start from the repository root:

```sh
flutter pub get
flutter analyze
flutter test
flutter build web --release
export TASKHUB_DOMAIN=taskhub.example.com
docker compose config
docker compose up -d --build
curl --fail "https://$TASKHUB_DOMAIN/health"
```

Replace the example domain with your domain. Web requests use the same origin.
For Android release builds use `--dart-define=TASKHUB_API_URL=https://YOUR_DOMAIN`.

## Backup and restore

Run daily on the host (e.g. a systemd timer or cron), and before each upgrade:

```sh
docker compose exec -T api python -m backend.backup /data/taskhub.sqlite3 /data/snapshot.sqlite3
mkdir -p backups
chmod 700 backups
docker compose cp api:/data/snapshot.sqlite3 backups/snapshot.sqlite3
chmod 600 backups/snapshot.sqlite3
```

Copy snapshots to encrypted off-host storage with dated names. The command creates
one consistent SQLite snapshot using the backup API, including committed WAL data.
It does not configure off-host credentials or retention automatically.

Restore into a new volume/deployment first and verify login, groups and planner
state. Stop API writes before replacing the live DB; retain the previous volume
for rollback. Never overwrite a running database or reuse stale WAL/SHM files.

## Verification and limitations

Run `python -m unittest discover -s backend/tests -v`. Deployment must also pass
Docker build, HTTPS, real-device login, persistence across restart, and restore
checks on the target host. No target host is configured by this repository.

Auth endpoints allow 20 attempts per IP per 15 minutes, persisted in SQLite.
Shared campus IPs share the allowance. Monitor 429 responses before rollout.
Sessions expire after 30 days; expired sessions are pruned during auth attempts.
Schema version 2 upgrades existing databases idempotently; newer schemas are
rejected to avoid accidental downgrade writes.

Compose runs a daily backup worker and exposes its backup freshness as container
health. Configure replication of the taskhub_backups volume to off-host storage.
Use deploy/check-health.sh on an independent monitor with TASKHUB_URL and optional
TASKHUB_ALERT_WEBHOOK. These infrastructure destinations are deployment settings.

See RELEASE_CHECKLIST.md for remaining verification on the actual target host.
