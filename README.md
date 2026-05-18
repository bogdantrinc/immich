# Setup Dependencies

> [!WARNING]
> Set `CADDY_DOMAIN` to your own domain.

```bash
CADDY_DOMAIN=localhost bash -c "$(curl -fsSL https://raw.githubusercontent.com/bogdantrinc/immich/main/setup.sh)"
```

# Start app

```bash
cd /opt/immich-app
docker compose up --detach
```

# Backup

> [!WARNING]
> [BorgBackup](https://borgbackup.readthedocs.io/en/stable/installation.html) must be installed on your remote machine.
>
> Replace `REMOTE_HOST` and `REMOTE_BACKUP_PATH` with your remote machine values.

```bash
REMOTE_HOST="user@localhost" REMOTE_BACKUP_PATH="/path/to/Borg-Backup" bash -c "$(curl -fsSL https://raw.githubusercontent.com/bogdantrinc/immich/main/backup.sh)"
```
