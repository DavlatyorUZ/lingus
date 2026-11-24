#!/usr/bin/env bash
set -euo pipefail
umask 077
base="${LINGOY_HOME:-/srv/lingoy}"
python3 "$(dirname "$0")/database_backup.py" backup "$base"
