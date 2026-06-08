#!/bin/sh
set -eu

MODULE=wireguard_webmin
TARGET=/usr/share/webmin/$MODULE

if [ ! -d /usr/share/webmin ]; then
  echo "Webmin directory /usr/share/webmin was not found" >&2
  exit 1
fi

rm -rf "$TARGET"
mkdir -p "$TARGET"
tar \
  --exclude='./.git' \
  --exclude='./dist' \
  --exclude='./*.wbm.gz' \
  --exclude='./*.tar.gz' \
  -cf - . | tar -xf - -C "$TARGET"
mkdir -p "/etc/webmin/$MODULE"
cp config "/etc/webmin/$MODULE/config"
find "$TARGET" -name install.sh -exec chmod 0755 {} \;
find "$TARGET" -name '*.cgi' -exec chmod 0755 {} \;
find "$TARGET" -name '*.pl' -exec chmod 0755 {} \;

if [ -d /etc/cron.d ]; then
  cat > /etc/cron.d/wireguard_webmin <<EOF
*/5 * * * * root $TARGET/expire_peers.pl >/dev/null 2>&1
EOF
  chmod 0644 /etc/cron.d/wireguard_webmin
fi

if [ -f /etc/webmin/webmin.acl ] && ! grep -q "^root:.* $MODULE\\b\\|^root:.*:.*\\b$MODULE\\b" /etc/webmin/webmin.acl; then
  perl -0pi -e 's/^(root: .*)$/$1 '"$MODULE"'/m' /etc/webmin/webmin.acl
fi

echo "Installed Webmin module to $TARGET"
echo "Restart Webmin if the module does not appear immediately."
