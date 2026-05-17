#!/usr/bin/env bash
set -e

# SSD Mount Setup
prompt_yesno() {
  while true; do
    read -r -p "$1 [Y/N]: " ans
    case "$ans" in
      [Yy]) return 0 ;;
      [Nn]) return 1 ;;
      *) echo "Please enter Y or N." ;;
    esac
  done
}

select_partition() {
  echo "Select storage partition:"
  mapfile -t choices < <(
    lsblk -prno NAME,SIZE,MOUNTPOINT,TYPE |
    awk '
      $4 == "part" {
        device = $1
        size   = $2
        mount  = $3

        output = device " (" size ")"

        if (mount != "")
          output = output " - " mount

        print output
      }
    '
  )
  
  if [ ${#choices[@]} -eq 0 ]; then
    echo "No storage partitions found." >&2
    exit 1
  fi

  for i in "${!choices[@]}"; do
    num=$((i + 1))
    echo "${num}) ${choices[i]}"
  done

  while true; do
    read -r -p "Partition number: " sel
    if [[ "${sel}" =~ ^[0-9]+$ ]] && [ "${sel}" -ge 1 ] && [ "${sel}" -le ${#choices[@]} ]; then
      PART=$(awk '{print $1}' <<<"${choices[sel-1]}")
      break
    fi
    echo "Please enter a valid number between 1 and ${#choices[@]}."
  done
}

mount_ssd() {
  select_partition

  if prompt_yesno "Format ${PART} as ext4? This will erase data."; then
    sudo umount "${PART}" 2>/dev/null || true
    sudo mkfs.ext4 -F "${PART}"
  fi

  UUID=$(sudo blkid -s UUID -o value "${PART}")
  MOUNT_POINT="/mnt/Immich"
  sudo mkdir -p "${MOUNT_POINT}"

  if ! grep -q "UUID=${UUID}" /etc/fstab; then
    echo "UUID=${UUID}  ${MOUNT_POINT}  ext4  defaults,noatime  0  2" | sudo tee -a /etc/fstab >/dev/null
  fi

  sudo mount -a
  if mountpoint -q "${MOUNT_POINT}"; then
    echo "Mounted ${PART} at ${MOUNT_POINT}"
  else
    echo "Failed to mount ${PART} at ${MOUNT_POINT}" >&2
    exit 1
  fi
}

mount_ssd

# Install dependencies
sudo apt update
sudo apt install -y ufw borgbackup

# Firewall Setup
sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

sudo ufw --force enable

# Immich App Setup
sudo mkdir -p /opt/immich-app

sudo curl -fsSL https://raw.githubusercontent.com/bogdantrinc/immich/main/Caddyfile -o /opt/immich-app/Caddyfile
sudo curl -fsSL https://raw.githubusercontent.com/bogdantrinc/immich/main/compose.yml -o /opt/immich-app/compose.yml
sudo curl -fsSL https://raw.githubusercontent.com/bogdantrinc/immich/main/.env.example -o /opt/immich-app/.env

sudo sed -i "s/^CADDY_DOMAIN=.*/CADDY_DOMAIN=${CADDY_DOMAIN:?}/" /opt/immich-app/.env

echo "Successfully set up Immich"
