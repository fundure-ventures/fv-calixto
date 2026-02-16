# Troubleshooting: OpenClaw on Fly.io

## Port Mismatch — CLI commands fail inside container

**Symptom:** `gateway closed (1006 abnormal closure)` when running CLI commands like `devices list` via `fly ssh console`.

**Cause:** The gateway runs on port 3000 (`--port 3000` in fly.toml), but CLI commands default to port 18789.

**Fix:** Add `OPENCLAW_GATEWAY_PORT = "3000"` to `[env]` in fly.toml. The `--port` flag controls the server; the env var tells the CLI where to connect.

---

## "pairing required" in Control UI

**Symptom:** `disconnected (1008): pairing required` when opening the dashboard.

**Cause:** Fly.io terminates TLS at its edge proxy and forwards plain HTTP to the container. The gateway sees a non-local, non-HTTPS connection and requires device pairing.

**Fix:** SSH into the container and approve the device:
```sh
fly ssh console
node dist/index.js devices list
node dist/index.js devices approve <device-id>
```
This works once the port mismatch (above) is fixed.

---

## Permission denied on `/data/openclaw.json`

**Symptom:** `EACCES: permission denied, open '/data/openclaw.json'` on startup.

**Cause:** The file was edited via `fly ssh console` (which runs as root), so it's owned by `root:root`. The app runs as the `node` user and can't read it.

**Fix:** After any SSH edit, fix ownership:
```sh
chown node:node /data/openclaw.json
```

**Prevention:** Edit config as the node user:
```sh
su -s /bin/bash node -c "vim /data/openclaw.json"
```
Or use the built-in CLI (runs as node, no permission issues):
```sh
node dist/index.js config set <key> <value>
```

---

## Workspace on ephemeral filesystem (lost on deploy)

**Symptom:** Agent memory/workspace files disappear after every deploy.

**Cause:** Default workspace resolves to `~/.openclaw/workspace`. If `HOME` points to `/home/node` (ephemeral), files are lost on redeploy.

**Fix:** Set `HOME` to a path on the persistent `/data` volume in fly.toml:
```toml
[env]
  HOME = "/data/home"
```
Workspace then resolves to `/data/home/.openclaw/workspace/` (persistent).

**Important:** Also check that `openclaw.json` doesn't have a hardcoded workspace path pointing to the old location:
```sh
grep workspace /data/openclaw.json
```
If it shows `/root/.openclaw/workspace` or `/home/node/.openclaw/workspace`, update it:
```sh
node dist/index.js config set agents.defaults.workspace /data/home/.openclaw/workspace
```

---

## gog CLI credentials not found by gateway

**Symptom:** Chat UI shows `stored credentials.json is missing client_id/client_secret` when agent tries to use gog.

**Cause:** gog was set up via SSH as root, so credentials saved to `/root/.config/gogcli/`. The gateway runs with `HOME=/data/home` and looks in `/data/home/.config/gogcli/`.

**Fix:** Copy credentials to the persistent location:
```sh
cp -r /root/.config/gogcli/* /data/home/.config/gogcli/
chown -R node:node /data/home/.config/gogcli
```

**Prevention:** Always run gog setup as the node user:
```sh
su -s /bin/bash node -c "gog auth credentials /path/to/client_secret.json"
su -s /bin/bash node -c "gog auth add you@gmail.com --services gmail,calendar,drive,contacts,docs,sheets"
```

**Verify:**
```sh
HOME=/data/home gog auth list
```

---

## Crash loop — can't SSH in to fix config

**Symptom:** Bad config causes the app to restart continuously, blocking SSH access.

**Fix:** Deploy with a dummy process to get shell access:
```toml
[processes]
  app = "sleep infinity"
```
Deploy, SSH in, fix the config, then restore the original process command and redeploy.

**Prevention:** Add a restart policy to fly.toml:
```toml
[restart]
  policy = "on-failure"
  max_retries = 3
```
This stops the machine after 3 failures instead of looping forever.

---

## General tips

- **Fly.io volumes** (`/data`) are only accessible from inside a running machine — no external mount.
- **SSH runs as root** — any files you create/edit need `chown node:node` after.
- **Use `su -s /bin/bash node -c "..."`** to run commands as the node user from SSH.
- **Use `config set`** instead of vim to avoid JSON syntax errors and permission issues.
- **Vim swap files:** If vim crashed, delete the swap: `rm /data/.openclaw.json.swp`
