#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Container entrypoint
# Sources both workspaces and delegates to run.sh or a shell.
# ─────────────────────────────────────────────────────────────────────────────
set -e

source /opt/vulcanexus/humble/setup.bash
source /home/cohan_ws/install/setup.bash

exec "$@"
