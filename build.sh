#!/bin/sh
set -eu

OUT=${1:-wireguard_webmin.wbm.gz}
TMP=${TMPDIR:-/tmp}/wireguard_webmin_build.$$

rm -rf "$TMP"
mkdir -p "$TMP"

tar \
  --exclude='./.git' \
  --exclude='./dist' \
  --exclude='./*.wbm.gz' \
  --exclude='./*.tar.gz' \
  -cf - . | tar -xf - -C "$TMP"

tar -czf "$OUT" -C "$TMP" .
rm -rf "$TMP"

echo "Built $OUT"
