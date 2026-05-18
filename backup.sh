#!/usr/bin/env bash

set -Eeuo pipefail

cd /opt/immich-app

export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes

source .env

required_vars=(
  REMOTE_HOST
  REMOTE_BACKUP_PATH
  UPLOAD_LOCATION
  DB_USERNAME
  CADDY_DOMAIN
)

for var in "${required_vars[@]}"; do
  [[ -n "${!var:-}" ]] || {
    echo "Missing required environment variable: $var"
    exit 1
  }
done

SSH_KEY="$HOME/.ssh/id_ed25519"

if [[ ! -f "$SSH_KEY" ]]; then
  echo "Generating SSH key at $SSH_KEY..."
  ssh-keygen -t ed25519 -N "" -f "$SSH_KEY"
fi

echo "Copying SSH key to $REMOTE_HOST..."
ssh-copy-id -i "$SSH_KEY.pub" "$REMOTE_HOST"

REPO="$REMOTE_HOST:$REMOTE_BACKUP_PATH/immich-borg"

ssh "$REMOTE_HOST" "test -d '$REMOTE_BACKUP_PATH'" || {
  echo "Remote backup path does not exist: $REMOTE_BACKUP_PATH"
  exit 1
}

maintenance_enabled=false

cleanup() {
  if [[ "$maintenance_enabled" == true ]]; then
    docker exec --tty immich_server immich-admin disable-maintenance-mode
  fi
}

trap cleanup EXIT

sudo mkdir --parents "$UPLOAD_LOCATION/database-backup"
sudo chmod 777 "$UPLOAD_LOCATION/database-backup"

if ! borg list "$REPO" >/dev/null 2>&1; then
  borg --verbose --progress init --encryption=none "$REPO"
fi

maintenance_output="$(docker exec --tty immich_server immich-admin enable-maintenance-mode)"
maintenance_enabled=true
maintenance_output="${maintenance_output//my.immich.app/$CADDY_DOMAIN}"
echo "$maintenance_output"

docker exec --tty immich_postgres pg_dumpall --clean --if-exists --username="$DB_USERNAME" > "$UPLOAD_LOCATION/database-backup/immich-database.sql"

borg create --verbose --progress "$REPO::{now}" "$UPLOAD_LOCATION" --exclude "$UPLOAD_LOCATION/thumbs/" --exclude "$UPLOAD_LOCATION/encoded-video/"
borg prune --verbose --progress --keep-weekly=4 --keep-monthly=3 "$REPO"
borg compact --verbose --progress "$REPO"
echo "Successfully backed up Immich data to $REPO"
