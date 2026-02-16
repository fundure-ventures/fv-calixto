#!/bin/sh
# Fly.io entrypoint — runs as root, then drops to the 'node' user.
#
# Why this exists:
# 1. The /data volume is mounted at runtime (not build time), so we can't
#    fix permissions in the Dockerfile. Files created via `fly ssh console`
#    (which runs as root) end up owned by root, and the node user can't
#    read them (e.g. openclaw.json → EACCES on startup).
# 2. We use `su -p` to preserve environment variables (especially HOME)
#    set in fly.toml [env]. Without -p, su resets HOME to /root or
#    /home/node, breaking workspace resolution (HOME=/data/home).
#
# Flow: chown /data → exec app as node (with env preserved)

chown -R node:node /data 2>/dev/null || true
exec su -s /bin/sh -p node -c "$*"
