#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'sudo bash deploy/bootstrap.sh'; exit 1; }
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx python3 sqlite3 curl ca-certificates xz-utils rsync unzip ufw fail2ban
if ! command -v node >/dev/null || [[ "$(node -p 'Number(process.versions.node.split(".")[0])')" -lt 24 ]]; then
  case "$(uname -m)" in x86_64) arch=x64;; aarch64) arch=arm64;; *) echo 'Arxitektura qo‘llanmaydi.'; exit 1;; esac
  temp="$(mktemp -d)"
  curl -fLsS https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt -o "$temp/SHASUMS256.txt"
  archive="$(awk -v suffix="linux-$arch.tar.xz" '$2 ~ suffix"$" {print $2}' "$temp/SHASUMS256.txt")"
  [[ "$archive" =~ ^node-v24\.[0-9]+\.[0-9]+-linux-(x64|arm64)\.tar\.xz$ ]] || exit 1
  curl -fLsS "https://nodejs.org/dist/latest-v24.x/$archive" -o "$temp/$archive"
  (cd "$temp"; awk -v file="$archive" '$2==file' SHASUMS256.txt | sha256sum -c -)
  mkdir -p /opt/lingoy-node
  tar -xJf "$temp/$archive" --strip-components=1 -C /opt/lingoy-node
  for tool in node npm npx; do ln -sf "/opt/lingoy-node/bin/$tool" "/usr/local/bin/$tool"; done
  rm -rf "$temp"
fi
npm install --global --prefix /usr/local pm2
id lingoy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash lingoy
install -d -o lingoy -g lingoy -m 750 /srv/lingoy /srv/lingoy/releases /srv/lingoy/shared /srv/lingoy/shared/data /srv/lingoy/shared/logs /srv/lingoy/shared/backups /srv/lingoy/incoming
chmod 755 /srv/lingoy /srv/lingoy/releases
install -d -m 755 /var/www/letsencrypt
if [[ ! -f /etc/nginx/sites-available/lingoy ]]; then
  cp "$(dirname "$0")/nginx-http.conf" /etc/nginx/sites-available/lingoy
fi
ln -sf /etc/nginx/sites-available/lingoy /etc/nginx/sites-enabled/lingoy
nginx -t
if [[ ! -e /etc/fail2ban/jail.d/lingoy.local ]]; then
  printf '[sshd]\nenabled = true\nbackend = systemd\n' > /etc/fail2ban/jail.d/lingoy.local
fi
systemctl enable --now nginx fail2ban
systemctl reload nginx
