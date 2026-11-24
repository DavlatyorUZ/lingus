#!/usr/bin/env bash
set -euo pipefail
umask 027
base="${LINGOY_HOME:-/srv/lingoy}"
source_dir="$(realpath "${1:-$(dirname "$0")/..}")"
[[ -f "$base/shared/.env" ]] || { echo 'Avval install.sh ni ishga tushiring.'; exit 1; }
mkdir -p "$base/releases" "$base/shared/data" "$base/shared/logs"
exec 9>"$base/shared/deploy.lock"
flock -n 9 || { echo 'Boshqa deploy jarayoni ishlamoqda.'; exit 1; }
release="$base/releases/$(date -u +%Y%m%dT%H%M%S)-$$"
mkdir "$release"
rsync -a --exclude='server/.env' --exclude='mobile/.env' --exclude='*.keystore' --exclude='server/data' --exclude='node_modules' --exclude='.dart_tool' --exclude='mobile/build' --exclude='.preview' "$source_dir/" "$release/"
ln -s "$base/shared/.env" "$release/server/.env"
ln -s "$base/shared/data" "$release/server/data"
cd "$release/server"
npm ci --omit=dev --no-audit --no-fund
npm run build
npm test
npm run preflight
[[ -f "$release/web/dist/index.html" && -s "$release/downloads/Lingoy.apk" ]] || { echo 'Paketda PWA yoki APK yetishmayapti.'; exit 1; }
bash "$release/deploy/backup.sh"
npm run migrate
chmod 755 "$release" "$release/web" "$release/downloads"
find "$release/web/dist" -type d -exec chmod 755 {} +
find "$release/web/dist" -type f -exec chmod 644 {} +
find "$release/downloads" -type f -exec chmod 644 {} +
previous="$(readlink -f "$base/current" 2>/dev/null || true)"
switched=0
rollback(){ local result=$?; if [[ $result -ne 0 && $switched -eq 1 && -n "$previous" && -d "$previous" ]]; then ln -s "$previous" "$base/current.rollback"; mv -Tf "$base/current.rollback" "$base/current"; pm2 startOrReload "$base/current/deploy/ecosystem.config.cjs" --update-env || true; echo 'Oldingi release qaytarildi.'; fi; exit "$result"; }
trap rollback EXIT
ln -s "$release" "$base/current.next"
mv -Tf "$base/current.next" "$base/current"
switched=1
pm2 startOrReload "$base/current/deploy/ecosystem.config.cjs" --update-env
healthy=0
for attempt in {1..20}; do
 if curl -fsS --max-time 3 http://127.0.0.1:8080/api/v1/health | python3 -c 'import json,sys;p=json.load(sys.stdin);assert p["status"]=="ready" and p["release_id"]==sys.argv[1]' "$(basename "$release")" 2>/dev/null; then healthy=1; break; fi
 sleep 1
done
[[ $healthy -eq 1 ]] || { echo 'Health tekshiruvi muvaffaqiyatsiz.'; exit 1; }
if [[ "${LINGOY_SKIP_PUBLIC_CHECK:-0}" != 1 ]]; then
  bash "$release/deploy/verify.sh"
fi
pm2 save
echo 'Release ishga tushdi. https://lingoy.uz'
