# Saki

A self-hosted Nginx reverse proxy that routes analytics and tracking requests through your own domain. Most adblockers block requests to known analytics domains like `googletagmanager.com`, `amplitude.com`, `clarity.ms`, etc. Saki proxies these requests through your infrastructure so they aren't blocked.

Runs as a single Docker container using Nginx Alpine.

## Supported Services

| Service | Route | Upstream Domain |
|---------|-------|-----------------|
| Google Tag Manager | `/googletagmanager/` | `www.googletagmanager.com` |
| Google Analytics | `/google-analytics/` | `www.google-analytics.com` |
| Amplitude CDN | `/amplitude-cdn/` | `cdn.amplitude.com` |
| Amplitude API | `/amplitude-api/` | `api2.amplitude.com` |
| Mixpanel CDN | `/mixpanel-cdn/` | `cdn.mxpnl.com` |
| Mixpanel API | `/mixpanel-api/` | `api.mixpanel.com` |
| Microsoft Clarity | `/clarity/` | `www.clarity.ms` |
| PostHog JS | `/posthog-js/` | `us-assets.i.posthog.com` |
| PostHog API | `/posthog-api/` | `us.i.posthog.com` |

## Quick Start

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
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8765/googletagmanager/gtag/js?id=G-XXXXXXXX"

# Amplitude
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8765/amplitude-cdn/libs/analytics-browser-2.11.0-min.js.gz"

# Mixpanel
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8765/mixpanel-cdn/libs/mixpanel-2-latest.min.js"

# Microsoft Clarity
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8765/clarity/s/0.7.59/clarity.js"

# PostHog
curl -s -o /dev/null -w "%{http_code}" "http://localhost:8765/posthog-js/static/array.js"
```

All should return `200`.

## Usage Examples

Replace the original script domains in your website with the proxy URL.

### Google Tag Manager

```html
<!-- Before -->
<script src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXX"></script>

<!-- After -->
<script src="https://your-proxy.example.com/googletagmanager/gtag/js?id=G-XXXXXXXX"></script>
```

### Amplitude

```html
<!-- Before -->
<script src="https://cdn.amplitude.com/libs/analytics-browser-2.11.0-min.js.gz"></script>

<!-- After -->
<script src="https://your-proxy.example.com/amplitude-cdn/libs/analytics-browser-2.11.0-min.js.gz"></script>
```

### Mixpanel

```html
<!-- Before -->
<script src="https://cdn.mxpnl.com/libs/mixpanel-2-latest.min.js"></script>

<!-- After -->
<script src="https://your-proxy.example.com/mixpanel-cdn/libs/mixpanel-2-latest.min.js"></script>
```

### Microsoft Clarity

```html
<!-- Before (inside Clarity snippet) -->
<script>
  // Change the script source domain in the Clarity snippet
  // from: https://www.clarity.ms/tag/PROJECT_ID
  // to:   https://your-proxy.example.com/clarity/tag/PROJECT_ID
</script>
```

### PostHog

```js
// Before
posthog.init('YOUR_KEY', { api_host: 'https://us.i.posthog.com' })

// After
posthog.init('YOUR_KEY', { api_host: 'https://your-proxy.example.com/posthog-api' })
```

## Configuration

### Change the port

Edit `docker-compose.yml` and change the host port:

```yaml
ports:
  - "3000:80"  # Change 8765 to any port
```

### Add a new service

Edit `nginx.conf` and add a new location block:

```nginx
# Example: Facebook Pixel
location /facebook/ {
    proxy_pass https://connect.facebook.net/;
    proxy_set_header Host connect.facebook.net;
    proxy_set_header Referer "";

    sub_filter 'connect.facebook.net' '$host/facebook';
    sub_filter_once off;
    sub_filter_types application/javascript text/javascript;
}
```

Then rebuild:

```bash
docker compose up -d --build
```

## What Gets Forwarded

The proxy forwards all client details to the upstream analytics service so tracking works correctly:

- `User-Agent` — browser/device identity
- `Cookie` / `Set-Cookie` — session tracking
- `Accept-Language` — language preference
- `X-Real-IP` — client IP address
- `X-Forwarded-For` — proxy chain
- `X-Forwarded-Proto` — original protocol

JavaScript responses also have domain references rewritten via `sub_filter` so that internal script references point back through the proxy.

## Production Deployment

For production, put this behind your own domain with HTTPS:

1. Deploy the container to your server
2. Point a subdomain (e.g., `t.yourdomain.com`) to the server
3. Use a reverse proxy (Caddy, Traefik, or another Nginx) with TLS termination in front of the container
4. Update your website scripts to use `https://t.yourdomain.com/...`

## Project Structure

```
saki/
├── Dockerfile          # Nginx Alpine image
├── docker-compose.yml  # Container configuration
├── nginx.conf          # Proxy routes and settings
├── LICENSE             # MIT License
└── README.md
```

## License

[MIT](LICENSE)
