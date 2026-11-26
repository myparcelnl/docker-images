#!/usr/bin/env bash
# Prints the locales of the installed plugin, one per line, from its i18n/*.csv files.
#   locales.sh [<plugin dir>]   Default: vendor/myparcelnl/magento in the current directory.
set -euo pipefail

plugin_dir="${1:-vendor/myparcelnl/magento}"

shopt -s nullglob
files=("$plugin_dir"/i18n/*.csv)

if [ ${#files[@]} -eq 0 ]; then
  echo "No i18n/*.csv files in $plugin_dir" >&2
  exit 1
fi

for file in "${files[@]}"; do
  basename "$file" .csv
done | sort
