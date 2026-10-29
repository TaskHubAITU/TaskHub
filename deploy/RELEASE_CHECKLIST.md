# Release acceptance

Implemented: account-scoped personal planner cache and cloud sync, explicit
revision conflicts, guest import, secure session storage, password change,
single-use recovery codes, password-confirmed account deletion, API limits,
versioned database initialization, HTTPS proxy configuration, daily consistent
backups and independent HTTP health-check script.

Recovery is by an explicitly generated recovery code, not email. Users must save
the code before losing access. Email addresses are account identifiers and are
not verified. Do not advertise email-based recovery.

The owner must provide infrastructure configuration for deployment: domain/DNS,
server access, off-host backup destination and alert webhook. These values must
not be committed. Backup snapshots currently remain in the Docker backup volume;
replicate that volume to separately managed storage and define retention.

Before marking a release ready:
- Python API tests, Flutter analyze/tests and web build pass.
- Container image builds and Caddy config validates.
- Test HTTPS registration, login, planner changes on two devices and conflicts.
- Confirm pending edits survive app restart and an offline period.
- Confirm guest data stays separate from every account.
- Exercise recovery, password change and deletion on test accounts.
- Restore a snapshot into a separate deployment and check its data.
- Configure external monitoring and test an alert.
- Check API limits under expected campus traffic and tune before public launch.

Do not infer production verification from passing unit tests. Record deployment
and two-device acceptance results for the actual release host.
