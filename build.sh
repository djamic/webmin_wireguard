#!/bin/sh
set -eu

OUT=${1:-wireguard_webmin.wbm.gz}
TMP=${TMPDIR:-/tmp}/wireguard_webmin_build.$$
MODULE=wireguard_webmin

rm -rf "$TMP"
mkdir -p "$TMP/$MODULE"

tar \
  --exclude='./.git' \
  --exclude='./dist' \
  --exclude='./*.wbm.gz' \
  --exclude='./*.tar.gz' \
  -cf - . | tar -xf - -C "$TMP/$MODULE"

tar -czf "$OUT" -C "$TMP" "$MODULE"
rm -rf "$TMP"

echo "Built $OUT"
