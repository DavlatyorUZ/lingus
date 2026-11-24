#!/usr/bin/env bash
set -euo pipefail
base="${LINGOY_HOME:-/srv/lingoy}"
attempts="${LINGOY_HEALTH_ATTEMPTS:-10}"
[[ "$attempts" =~ ^([1-9]|[12][0-9]|30)$ ]] || { echo 'Health urinishlari 1–30 oralig‘ida bo‘lsin.' >&2; exit 1; }
healthy=0
for ((attempt=1; attempt<=attempts; attempt++)); do
 if curl -fsS --max-time 3 http://127.0.0.1:8080/api/v1/health 2>/dev/null | python3 -c 'import json,sys
try:
 sys.exit(0 if json.load(sys.stdin).get("status")=="ready" else 1)
except (ValueError,AttributeError):
 sys.exit(1)'; then healthy=1; break; fi
 if ((attempt<attempts)); then sleep 1; fi
done
[[ $healthy -eq 1 ]] || { echo 'Lingoy API tayyor emas. PM2 va backend loglarini tekshiring.' >&2; exit 1; }
echo 'Lingoy API: OK'
df -h "$base"
pm2 describe lingoy-api
