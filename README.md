# Saki

A self-hosted Nginx reverse proxy that routes analytics and tracking requests through your own domain. Most adblockers block requests to known analytics domains like `googletagmanager.com`, `amplitude.com`, `clarity.ms`, etc. Saki proxies these requests through your infrastructure so they aren't blocked.

Runs as a single Docker container using Nginx Alpine. The container listens on the `PORT` environment variable, defaulting to `80` if not set — making it compatible with any platform that injects a port at runtime (Railway, Render, Fly.io, Heroku, etc.).

## Supported Services

| Service            | Default Route | Env Variable     | Upstream Domain            |
| ------------------ | ------------- | ---------------- | -------------------------- |
| Google Tag Manager | `/tg/`        | `ROUTE_GTM`      | `www.googletagmanager.com` |
| Google Analytics   | `/an/`        | `ROUTE_GA`       | `www.google-analytics.com` |
| Amplitude CDN      | `/acdn/`      | `ROUTE_AMP_CDN`  | `cdn.amplitude.com`        |
| Amplitude API      | `/aapi/`      | `ROUTE_AMP_API`  | `api2.amplitude.com`       |
| Mixpanel CDN       | `/mxc/`       | `ROUTE_MIX_CDN`  | `cdn.mxpnl.com`            |
| Mixpanel API       | `/mxa/`       | `ROUTE_MIX_API`  | `api.mixpanel.com`         |
| Microsoft Clarity  | `/cla/`       | `ROUTE_CLARITY`  | `www.clarity.ms`           |
| PostHog JS         | `/phj/`       | `ROUTE_PH_JS`    | `us-assets.i.posthog.com`  |
| PostHog API        | `/pha/`       | `ROUTE_PH_API`   | `us.i.posthog.com`         |

> **Why short routes?** Adblockers match URL patterns — paths like `/googletagmanager/` or `/google-analytics/` get blocked even on your own domain. The default routes use short, neutral prefixes. You can customise them further via environment variables (see [Customise route paths](#customise-route-paths)).

## Get Started

### Docker Hub (recommended)

```bash
docker run -d --name saki -p 8765:80 --restart unless-stopped rajnandan1/saki:latest
```

Or with Docker Compose, create a `docker-compose.yml`:

```yaml
services:
    saki:
        image: rajnandan1/saki:latest
        container_name: saki
        ports:
            - "8765:80"
        restart: unless-stopped
```

```bash
docker compose up -d
```

### Build from source

```bash
git clone https://github.com/rajnandan1/saki.git
cd saki
docker compose up -d --build
```

The proxy is now running on `http://localhost:8765`.

### Verify

```bash
# Health check
curl http://localhost:8765/health

# Google Tag Manager
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8765/tg/gtag/js?id=G-XXXXXXXX"

# Amplitude
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8765/acdn/libs/analytics-browser-2.11.0-min.js.gz"

# Mixpanel
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8765/mxc/libs/mixpanel-2-latest.min.js"

# Microsoft Clarity
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8765/cla/s/0.7.59/clarity.js"

# PostHog
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8765/phj/static/array.js"
```

All should return `200`.

## Usage Examples

Replace the original script domains in your website with the proxy URL.

### Google Tag Manager

```html
<!-- Before -->
<script src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXX"></script>

<!-- After -->
<script src="https://your-proxy.example.com/tg/gtag/js?id=G-XXXXXXXX"></script>
```

### Amplitude

```html
<!-- Before -->
<script src="https://cdn.amplitude.com/libs/analytics-browser-2.11.0-min.js.gz"></script>

<!-- After -->
<script src="https://your-proxy.example.com/acdn/libs/analytics-browser-2.11.0-min.js.gz"></script>
```

### Mixpanel

```html
<!-- Before -->
<script src="https://cdn.mxpnl.com/libs/mixpanel-2-latest.min.js"></script>

<!-- After -->
<script src="https://your-proxy.example.com/mxc/libs/mixpanel-2-latest.min.js"></script>
```

### Microsoft Clarity

```html
<!-- Before (inside Clarity snippet) -->
<script>
    // Change the script source domain in the Clarity snippet
    // from: https://www.clarity.ms/tag/PROJECT_ID
    // to:   https://your-proxy.example.com/cla/tag/PROJECT_ID
</script>
```

### PostHog

```js
// Before
posthog.init("YOUR_KEY", { api_host: "https://us.i.posthog.com" });

// After
posthog.init("YOUR_KEY", {
    api_host: "https://your-proxy.example.com/pha",
});
```

## Configuration

### Change the port

**Locally** — edit `docker-compose.yml` and change the host port:

```yaml
ports:
    - "3000:80" # Change 8765 to any port
```

**On a PaaS platform** — set the `PORT` environment variable to whatever port the platform expects the container to listen on. The container will bind to that port automatically.

### Customise route paths

Set environment variables to override the default route prefixes. This is useful if an adblocker still catches a default route, or you simply want your own naming:

```yaml
services:
    saki:
        image: rajnandan1/saki:latest
        ports:
            - "8765:80"
        environment:
            - ROUTE_GTM=mytagscript
            - ROUTE_GA=mydata
```

The full list of variables and their defaults is in the [Supported Services](#supported-services) table.

### Add a new service

Edit `templates/default.conf.template` and add a new location block:

```nginx
# Example: Facebook Pixel
location /${ROUTE_FB}/ {
    proxy_pass https://connect.facebook.net/;

    sub_filter 'connect.facebook.net' '$host/${ROUTE_FB}';
    sub_filter_once off;
    sub_filter_types application/javascript text/javascript;
}
```

Add a default in the `Dockerfile`:

```dockerfile
ENV ROUTE_FB=fb
```

Then rebuild:

```bash
docker compose up -d --build
```

> `nginx.conf` contains the top-level http settings. `templates/default.conf.template` contains the server block and all location routes — this file is processed at container startup with `envsubst` to resolve environment variables like `${PORT}` and `${ROUTE_*}`.

## What Gets Forwarded

The proxy forwards all client details to the upstream analytics service so tracking works correctly:

- `User-Agent` — browser/device identity
- `Cookie` / `Set-Cookie` — session tracking
- `Accept-Language` — language preference
- `X-Real-IP` — client IP address
- `X-Forwarded-For` — proxy chain
- `X-Forwarded-Proto` — original protocol

When running behind a platform load balancer (Railway, Render, etc.), Saki uses the Nginx `real_ip` module to recover the original visitor IP from `X-Forwarded-For` and forward it upstream so geo data reflects your users instead of the proxy location.

> **Security note:** The `set_real_ip_from` directives in `nginx.conf` control which sources are trusted to set `X-Forwarded-For`. By default they allow RFC 1918 private ranges. If your load balancer uses public IPs, replace these with the actual LB egress ranges. Never use `0.0.0.0/0` in production — it lets any client spoof their IP.

JavaScript responses also have domain references rewritten via `sub_filter` so that internal script references point back through the proxy.

## Production Deployment

For production, put this behind your own domain with HTTPS:

1. Deploy the container to your server
2. Point a subdomain (e.g., `t.yourdomain.com`) to the server
3. Use a reverse proxy (Caddy, Traefik, or another Nginx) with TLS termination in front of the container
4. Update your website scripts to use `https://t.yourdomain.com/...`

### PaaS platforms (Railway, Render, Fly.io, Heroku, etc.)

Most PaaS platforms inject a `PORT` environment variable and expect the container to listen on it. Saki reads `PORT` automatically at startup — no extra configuration is needed. Just deploy the container and make sure your platform's networking points to the same port the container is listening on (the value of `PORT`).

## Project Structure

```
saki/
├── Dockerfile                          # Nginx Alpine image
├── docker-compose.yml                  # Container configuration
├── nginx.conf                          # Top-level http config
├── templates/
│   └── default.conf.template           # Server block with PORT and all location routes
├── LICENSE                             # MIT License
└── README.md
```

## License

[MIT](LICENSE)
