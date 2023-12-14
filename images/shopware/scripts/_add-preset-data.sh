#!/usr/bin/env bash

# todo add more initial data here
add-preset-data() {
  h1 "Adding preset data..."
  composer require shopware/dev-tools && \
  APP_ENV=prod bin/console framework:demodata
  APP_ENV=prod bin/console dal:refresh:index

  php bin/console "$verbosity" user:create \
    "$ADMIN_USER" \
    --admin \
    --email "$ADMIN_EMAIL" \
    --password "$ADMIN_PASSWORD" \
    --firstName "$ADMIN_FIRST_NAME" \
    --lastName "$ADMIN_LAST_NAME"

  php bin/console "$verbosity" user:create \
    "$CUSTOMER_USER" \
    --email "$CUSTOMER_EMAIL" \
    --password "$CUSTOMER_PASSWORD" \
    --firstName "$CUSTOMER_FIRST_NAME" \
    --lastName "$CUSTOMER_LAST_NAME"
}
