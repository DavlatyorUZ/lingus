#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Ishga tushirish: sudo bash install.sh'; exit 1; }
source_dir="$(cd "$(dirname "$0")" && pwd)"
bash "$source_dir/deploy/bootstrap.sh"
if [[ ! -f /srv/lingoy/shared/.env ]]; then
  install -o lingoy -g lingoy -m 600 "$source_dir/server/.env" /srv/lingoy/shared/.env
else
  echo 'Mavjud server .env sozlamalari saqlandi. Yangi Gemini kaliti kerak bo‘lsa shared/.env ni yangilang.'
fi
stage="/srv/lingoy/incoming/$(date -u +%Y%m%dT%H%M%S)-$$"
mkdir -p "$stage"
rsync -a --exclude='server/.env' --exclude='mobile/.env' --exclude='*.keystore' --exclude='node_modules' --exclude='.dart_tool' --exclude='mobile/build' --exclude='.preview' "$source_dir/" "$stage/"
chown -R lingoy:lingoy "$stage"
runuser -u lingoy -- env LINGOY_SKIP_PUBLIC_CHECK=1 bash "$stage/deploy/deploy.sh" "$stage"
certbot certonly --webroot -w /var/www/letsencrypt -d lingoy.uz -d www.lingoy.uz --email lingoy.uz@gmail.com --agree-tos --no-eff-email
cp "$stage/deploy/nginx.conf" /etc/nginx/sites-available/lingoy
nginx -t
systemctl reload nginx
systemctl enable --now certbot.timer
env PATH="$PATH" pm2 startup systemd -u lingoy --hp /home/lingoy
runuser -u lingoy -- pm2 save
echo 'Sayt joylashtirildi. Endi ommaviy HTTPS, PWA, APK, SMTP va AI tekshiriladi.'
if ! runuser -u lingoy -- bash /srv/lingoy/current/deploy/verify.sh; then
  echo 'Sayt joylashtirildi, lekin yakuniy avtomatik tekshiruv o‘tmadi. Yuqoridagi natijaga ko‘ra sozlamani tuzating va deploy/verify.sh ni qayta bajaring.' >&2
  exit 2
fi
echo 'Avtomatik tekshiruvlar o‘tdi: https://lingoy.uz — APK: https://lingoy.uz/downloads/Lingoy.apk'
echo 'Email kodi, Google orqali haqiqiy kirish va fizik Android sinovi qo‘lda tasdiqlanadi.'
