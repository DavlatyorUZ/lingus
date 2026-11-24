#!/usr/bin/env bash
set -euo pipefail
umask 077
base="$(realpath "${LINGOY_HOME:-/srv/lingoy}")"
backup="$(realpath "${1:?Tiklash uchun backup faylini kiriting.}")"
[[ "$backup" == "$base/shared/backups/"*.sqlite ]] || { echo 'Faqat shared/backups ichidagi nusxani tanlang.'; exit 1; }
python3 "$(dirname "$0")/database_backup.py" validate "$backup"
exec 9>"$base/shared/deploy.lock"
flock -n 9 || exit 1
previous=''
recover(){ local result=$?; if [[ $result -ne 0 ]]; then
  pm2 stop lingoy-api || true
  if [[ -n "$previous" && -d "$previous/data" ]]; then
    [[ ! -d "$base/shared/data" ]] || mv "$base/shared/data" "$previous/failed-new"
    mv "$previous/data" "$base/shared/data"
  fi
  if pm2 restart lingoy-api; then
    echo 'Tiklash tugamadi; oldingi baza qaytarildi va restart so‘raldi. Health holatini tekshiring.'
  else
    echo 'Tiklash tugamadi; baza qaytarildi, lekin PM2 restart ham bajarilmadi.' >&2
  fi
fi; exit "$result"; }
trap recover EXIT
pm2 stop lingoy-api
bash "$base/current/deploy/backup.sh"
previous="$base/shared/backups/before-restore-$(date -u +%Y%m%dT%H%M%S)-$$"
mkdir "$previous"
mv "$base/shared/data" "$previous/data"
mkdir -m 750 "$base/shared/data"
cp "$backup" "$base/shared/data/lingoy.sqlite"
chmod 600 "$base/shared/data/lingoy.sqlite"
python3 "$(dirname "$0")/database_backup.py" validate "$base/shared/data/lingoy.sqlite"
pm2 restart lingoy-api
bash "$base/current/deploy/healthcheck.sh"
