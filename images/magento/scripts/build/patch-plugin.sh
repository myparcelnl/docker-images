#!/usr/bin/env bash
# Applies patches/plugin-php84-nullable.patch to the installed plugin. Run it in the Magento root.
# Temporary until a plugin release has myparcelnl/magento PR #1015 (explicit nullable types for PHP 8.4).
# Writes the label suffix to /usr/local/share/magento-image/plugin-version-suffix.
set -euo pipefail

patch_file=/usr/local/lib/magento-patches/plugin-php84-nullable.patch
plugin_dir="${1:-vendor/myparcelnl/magento}"
suffix_file=/usr/local/share/magento-image/plugin-version-suffix

cd "$plugin_dir"

if git apply --check "$patch_file" 2>/dev/null; then
  git apply "$patch_file"
  echo "Applied $(basename "$patch_file")"
  printf '+php84-patch' > "$suffix_file"
elif git apply --reverse --check "$patch_file" 2>/dev/null; then
  echo "plugin-php84-nullable.patch is in the release; remove the patch"
  : > "$suffix_file"
else
  echo "$(basename "$patch_file") does not apply to the installed plugin, and is not in it either" >&2
  exit 1
fi
