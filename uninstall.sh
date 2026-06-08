#!/bin/sh
set -eu

MODULE=wireguard_webmin

rm -rf "/usr/share/webmin/$MODULE"
rm -rf "/etc/webmin/$MODULE"
rm -f /etc/cron.d/wireguard_webmin

if [ -f /etc/webmin/webmin.acl ]; then
  perl -0pi -e 's/\s+\Q'"$MODULE"'\E\b//g' /etc/webmin/webmin.acl
fi

rm -f /var/webmin/module.infos.cache

echo "Uninstalled $MODULE"
