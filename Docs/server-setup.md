# BoberHouse Server Setup

## Prerequisites
- macOS or Linux host with Swift 5.9 toolchain (or Docker)
- SQLite 3 available on the system (bundled with macOS/Linux)
- Apple Developer account with APNs key (token-based auth)
- Reverse proxy or firewall rule exposing port 8080 (or configure as needed)

## Environment Variables
Set the following variables before launching the server:

| Variable | Description |
| --- | --- |
| `SERVER_API_TOKEN` | Shared bearer token used by the app for authentication |
| `SQLITE_PATH` | Optional custom path for the database file (defaults to `boberhouse.sqlite`) |
| `APNS_KEY_ID` | Key ID for the APNs authentication key |
| `APNS_TEAM_ID` | Apple Developer Team ID |
| `APNS_AUTH_KEY_PATH` | Absolute path to the `.p8` APNs authentication key |
| `APNS_BUNDLE_ID` | iOS bundle identifier (e.g. `com.example.BoberHouse`) |
| `APNS_ENV` | `sandbox` or `production` |

## Local Build & Run
```bash
cd Server
swift run Run
```
The server listens on `http://127.0.0.1:8080` by default. Set `PORT` if you need another port.

## Docker Image
Create a container by adding the following `Dockerfile` in `Server/`:
```dockerfile
FROM swift:5.9
WORKDIR /app
COPY . .
RUN swift build -c release
CMD ["./.build/release/Run"]
```

Build and run:
```bash
docker build -t boberhouse-server .
docker run -d \
  -p 8080:8080 \
  -e SERVER_API_TOKEN=your-token \
  -e APNS_KEY_ID=ABC123 \
  -e APNS_TEAM_ID=TEAMID \
  -e APNS_AUTH_KEY_PATH=/keys/AuthKey.p8 \
  -e APNS_BUNDLE_ID=com.example.BoberHouse \
  -e APNS_ENV=production \
  -v /path/to/AuthKey.p8:/keys/AuthKey.p8:ro \
  -v /srv/boberhouse-data:/data \
  -e SQLITE_PATH=/data/boberhouse.sqlite \
  boberhouse-server
```

## Reverse Proxy (nginx)
```nginx
server {
    listen 443 ssl;
    server_name api.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Database Backups
- Copy `boberhouse.sqlite` periodically off-host.
- Enable SQLite write-ahead logging if running with high load: `PRAGMA journal_mode=WAL;`.

## Updating the App
- Rebuild the binary (`swift build -c release`) after pulling changes.
- Restart the systemd unit or Docker container so the new build is served.

## Systemd Unit (optional)
Create `/etc/systemd/system/boberhouse.service`:
```
[Unit]
Description=BoberHouse Sync API
After=network.target

[Service]
WorkingDirectory=/opt/boberhouse/Server
EnvironmentFile=/opt/boberhouse/server.env
ExecStart=/opt/boberhouse/Server/.build/release/Run
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable boberhouse.service
sudo systemctl start boberhouse.service
```

## GitHub Actions Deployment
- Workflow file: `.github/workflows/server-deploy.yml`.
- A self-hosted runner lives on the VPS under `/opt/apps/boberhouse/actions-runner`; start it via `./svc.sh start` (or `./run.sh` for ad-hoc).
- Jobs use `runs-on: self-hosted`, run tests via `docker run --rm swift:5.9 swift test --package-path Server`, rsync the repo into `/opt/apps/boberhouse`, then execute `docker compose build boberhouse && docker compose up -d boberhouse`.
- No registry or SSH secrets are required, but the runner user must belong to the `docker` group and have access to the repo directory.
