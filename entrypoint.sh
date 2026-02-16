#!/bin/sh
# Fix /data volume permissions so the node user can read/write config and workspace files.
# This handles files created by root via SSH (vim edits, manual copies, etc.).
chown -R node:node /data 2>/dev/null || true
exec su -s /bin/sh node -c "$*"
