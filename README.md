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
