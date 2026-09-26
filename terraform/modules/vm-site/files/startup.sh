#!/bin/bash
# Runs on every boot. Installs nginx once, then writes the site from metadata.
set -euo pipefail

if ! command -v nginx >/dev/null 2>&1; then
  apt-get update -q
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q nginx-light
fi

MD="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
fetch() { curl -sf -H "Metadata-Flavor: Google" "$MD/$1"; }

fetch site-index-html > /var/www/html/index.html
fetch site-404-html   > /var/www/html/404.html

cat > /etc/nginx/sites-available/default <<'EOF'
server {
  listen 80 default_server;
  root /var/www/html;
  index index.html;
  server_tokens off;
  error_page 404 /404.html;
  location / {
    try_files $uri $uri/ =404;
  }
}
EOF

systemctl enable nginx
systemctl restart nginx