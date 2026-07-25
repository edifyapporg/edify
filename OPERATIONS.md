# Operations Runbook

Internal operations notes for running edify in production — a runbook for whoever operates the
infrastructure, **not** end-user documentation.

edify is a single Rails app hosted on a DigitalOcean droplet managed by Hatchbox, fronted by Cloudflare.
Unlike a load-balanced setup, it runs as **one web process** (Puma) on one app server, and background jobs
run **inside** that Puma process via Solid Queue — so the web process is effectively the whole app.

```
Cloudflare  ->  app server (Caddy)  ->  Puma   (Solid Queue runs inside Puma)
```

The app server is **shared with another Hatchbox app**, so anything that regenerates that server's Caddy
config — a deploy, or a Hatchbox "Update configuration" — affects both apps at once (see "Shared app
droplet" below).

Hostnames, IPs, and ports are written as placeholders (`<app-host>`, `<port>`, `<site>`) — this file is in
a public repository. Keep it that way.

---

## Web app on Hatchbox (Caddy → Puma)

The app server runs a **local Caddy** that reverse-proxies to **Puma** on `127.0.0.1:<port>`
(socket-activated). Two Hatchbox behaviors have caused a full outage here; check both whenever the site
404s on every route or the web process won't start.

### The reverse proxy is only generated for a "web role" process

Hatchbox **omits the `reverse_proxy`** from the server's Caddy config — serving `public/` as static files,
so **every route returns 404** — if the app has **no process assigned to the `web` role**. Assign the web
process to the **web role**, not directly to a specific server; a directly-assigned process can be read as
a static site and lose its proxy on the next config regeneration.

Diagnose on the app server:
```bash
curl -s localhost:2019/config/ | jq '[.. | objects | select(.handler? == "reverse_proxy")] | length'
```
`0` means Caddy has no proxy at all (static-only). Puma itself may be fine — confirm by hitting it directly
(bypassing Caddy), with the forwarded-proto header so Rails' `force_ssl` doesn't 301 you:
```bash
curl -sI http://127.0.0.1:<port>/ -H 'Host: <site>' -H 'X-Forwarded-Proto: https'   # 200/redirect => app fine, Caddy is the problem
```
Fix by ensuring a web-role process exists, then redeploy so the config regenerates with the proxy.

### The web process command must bind localhost explicitly

`config/puma.rb` uses `port ENV.fetch("PORT")` with no host, and **Puma 8 defaults that to `tcp://[::]:<port>`**
(all interfaces) when a non-loopback IPv6 interface exists. That default breaks this setup two ways: it
**doesn't match** the `127.0.0.1:<port>` systemd socket (so socket activation can't hand off the fd) and it
**collides** with it → a Puma `EADDRINUSE` crash loop — and it exposes the port on all interfaces. So the
Hatchbox **web process command binds localhost explicitly**:
```
bundle exec puma -C config/puma.rb -b tcp://127.0.0.1:${PORT}
```
Keep the `-b tcp://127.0.0.1:${PORT}` flag. The bare `bundle exec puma -C config/puma.rb` (no `-b`) is the
broken form. Keep socket activation **enabled** — the reverse-proxy detection relies on it; disabling it is
not a valid workaround.

### Verifying the app on the server

```bash
ss -ltn | grep :<port>                                                  # expect 127.0.0.1:<port> (NOT *: or [::]), Recv-Q 0
journalctl --user -u edify-web --since "5 min ago" --no-pager \
  | grep -iE 'Activated|Address already in use'                         # "Activated tcp://127.0.0.1:<port>", no EADDRINUSE
systemctl --user show edify-web -p NRestarts,ActiveState,SubState       # NRestarts stable, active/running
curl -s localhost:2019/config/ | jq '[.. | objects | select(.handler? == "reverse_proxy") | .upstreams]'   # dials 127.0.0.1:<port>
curl -s -o /dev/null -w '%{http_code}\n' https://<site>/                # 200
```
`Activated tcp://127.0.0.1:<port>` confirms socket activation is engaged (Puma reused the systemd socket
fd). From off-box, `curl -m5 http://<app-host>:<port>/` should refuse/time out (`000`) — the app port must
not be internet-reachable.

### Emergency stopgap: hand-load a corrected Caddyfile

If the server's Caddy is stuck without its `reverse_proxy` and you can't wait for a Hatchbox fix, POST a
corrected Caddyfile to the admin API to restore service immediately:
```bash
curl --max-time 15 -s --fail-with-body -X POST -H 'Content-Type: text/caddyfile' \
  localhost:2019/load --data-binary @/path/to/Caddyfile
```
This is a **stopgap** — the next deploy or config update on that box overwrites it — so still fix the root
cause (a missing web-role process, or a bind command without `-b 127.0.0.1`).

---

## Background jobs run inside Puma

Production runs Solid Queue **in-process** inside Puma (`plugin :solid_queue` in `config/puma.rb`, gated
on `SOLID_QUEUE_IN_PUMA`) rather than as a standalone worker, so:

- If the web process is down, **job processing is down too**.
- Restarting or redeploying the web process pauses and resumes jobs with it.

(The `worker:` line in `Procfile.dev` is for local development only.)

---

## Shared app droplet

The app server also hosts another Hatchbox app. Its Caddy config is generated for **all** apps on the box,
so a Hatchbox **"Update configuration"** or any app's **deploy** regenerates the shared Caddyfile — and the
web-role / reverse-proxy issue above can drop the proxy for **every** app on the server at once (that is how
a prior outage took down both apps simultaneously). After any such action, re-verify the proxy survived:
```bash
curl -s localhost:2019/config/ | jq '[.. | objects | select(.handler? == "reverse_proxy")] | length'   # expect the number of apps on the box
```

---

## Cloudflare & TLS

Cloudflare fronts the site. `config.assume_ssl` and `config.force_ssl` are on, so Rails trusts the
`X-Forwarded-Proto: https` that Caddy sets and won't redirect-loop. Caddy holds the Cloudflare IP ranges as
`trusted_proxies` (so client IPs resolve correctly) and does the **apex → www redirect** in its own config
(`redir` from the bare domain to `www`). If ACME cert renewal ever fails behind Cloudflare (tls-alpn-01
can't negotiate; http-01 gets intercepted), the fix is a Cloudflare Origin CA cert or a DNS-01 challenge.
