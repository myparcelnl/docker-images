#!/usr/bin/env bash
# Deploys static content for luma and backend in all plugin locales, without a database. Run it in the Magento root.
# Static content deploy reads the websites and themes from the database, or from app/etc/config.php
# when they are there. This script adds them to config.php for the deploy only, and then restores the
# file: scopes in config.php would make app:config:import replace the websites that the seed creates.
# Without a database, the deploy also writes an env.php with only cache_types; the script removes it.
set -euo pipefail


config=app/etc/config.php
backup="$(mktemp)"
cp "$config" "$backup"
had_env=0
[ -e app/etc/env.php ] && had_env=1

restore() {
  cp "$backup" "$config"
  rm -f "$backup"
  [ "$had_env" = 1 ] || rm -f app/etc/env.php
}
trap restore EXIT

php -r '
$file = $argv[1];
$config = require $file;
$config["scopes"] = [
    "websites" => [
        "admin" => ["website_id" => "0", "code" => "admin", "name" => "Admin", "sort_order" => "0", "default_group_id" => "0", "is_default" => "0"],
        "base" => ["website_id" => "1", "code" => "base", "name" => "Main Website", "sort_order" => "0", "default_group_id" => "1", "is_default" => "1"],
    ],
    "groups" => [
        0 => ["group_id" => "0", "website_id" => "0", "name" => "Default", "root_category_id" => "0", "default_store_id" => "0", "code" => "default"],
        1 => ["group_id" => "1", "website_id" => "1", "name" => "Main Website Store", "root_category_id" => "2", "default_store_id" => "1", "code" => "main_website_store"],
    ],
    "stores" => [
        "admin" => ["store_id" => "0", "code" => "admin", "website_id" => "0", "group_id" => "0", "name" => "Admin", "sort_order" => "0", "is_active" => "1"],
        "default" => ["store_id" => "1", "code" => "default", "website_id" => "1", "group_id" => "1", "name" => "Default Store View", "sort_order" => "0", "is_active" => "1"],
    ],
];
$theme = fn (string $area, string $path, string $title, ?string $parent) => [
    "parent_id" => $parent, "theme_path" => $path, "theme_title" => $title, "is_featured" => "0",
    "area" => $area, "type" => "0", "code" => $path,
];
$config["themes"] = [
    "adminhtml/Magento/backend" => $theme("adminhtml", "Magento/backend", "Magento 2 backend", null),
    "frontend/Magento/blank" => $theme("frontend", "Magento/blank", "Magento Blank", null),
    "frontend/Magento/luma" => $theme("frontend", "Magento/luma", "Magento Luma", "Magento/blank"),
];
file_put_contents($file, "<?php\nreturn " . var_export($config, true) . ";\n");
' "$config"

# shellcheck disable=SC2046 # one argument per locale
bin/magento setup:static-content:deploy -f --jobs=4 \
  --theme Magento/luma --theme Magento/backend \
  $(/usr/local/lib/magento-scripts/build/locales.sh)
