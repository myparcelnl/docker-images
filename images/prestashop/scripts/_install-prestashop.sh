#!/usr/bin/env bash

install-prestashop() {
  h1 "Starting PrestaShop installation"

  if ! wait-for-it -q -t 0 "$DB_HOST:$DB_PORT"; then
    h2 "Waiting for database..."
    wait-for-it -q -t 30 "$DB_HOST:$DB_PORT"
    h2 "Database is ready."
  fi

  if [ -f ./config/settings.inc.php ] && [ -f install.lock ]; then
    h2 "PrestaShop is installed, but install.lock is still present. Installation may not have been successful."
    exit 1
  elif [ ! -f ./config/settings.inc.php ] && [ -f install.lock ]; then
    h2 "Installation is already in progress."
    exit 1
  elif [ -f ./config/settings.inc.php ] && [ ! -f install.lock ]; then
    h2 "PrestaShop is already installed."
    return
  fi

  touch install.lock

  if [ "$PS_FOLDER_ADMIN" != "admin" ] && [ -d "${ROOT_DIR}/admin" ]; then
      h2 "Renaming admin folder to $PS_FOLDER_ADMIN...";
      sudo -u www-data -s mv "${ROOT_DIR}/admin" "${ROOT_DIR}/$PS_FOLDER_ADMIN/"
  fi

  reset-permissions

  h2 "Installing PrestaShop, this can take +/- 1 minute..."
  start=$(date +%s)

  composer install --no-plugins --no-interaction

  sudo -u www-data -s php install-dev/index_cli.php \
    --all_languages="$PS_ALL_LANGUAGES" \
    --country="$PS_COUNTRY" \
    --domain="$PS_DOMAIN" \
    --language="$PS_LANGUAGE" \
    --newsletter=0 \
    --send_email=0 \
    --ssl="$PS_ENABLE_SSL" \
    --email="$PS_ADMIN_MAIL" \
    --firstname="Mr." \
    --lastname="Parcel" \
    --password="$PS_ADMIN_PASSWORD" \
    --db_clear="$PS_DB_CLEAR" \
    --db_create="$PS_DB_CREATE" \
    --db_name="$DB_NAME" \
    --db_password="$DB_PASSWORD" \
    --db_server="$DB_HOST" \
    --db_user="$DB_USER" \
    --prefix="$DB_PREFIX"

  if [ $? -ne 0 ]; then
    rm -f install.lock ./config/settings.inc.php
    h2 "PrestaShop installation failed."
    exit 1
  fi

  build-themes

  reset-permissions

  end=$(date +%s)
  runtime=$((end-start))

  h2 "PrestaShop installation succeeded in $runtime seconds."
  rm install.lock
}
