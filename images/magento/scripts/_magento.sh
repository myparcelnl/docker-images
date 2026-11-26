# Install, upgrade and configuration steps of the start sequence. Run in /var/www/html.

INSTALL_MARKER=dev/myparcel_image/install_complete
UPGRADED=0

# Returns 0 when the database has Magento tables. Stops the start when the query fails.
database_is_installed() {
  local tables
  tables="$(db_query "SHOW TABLES LIKE 'core_config_data'")" || fail "Cannot read the database $DB_NAME on $DB_HOST"
  [ -n "$tables" ]
}

seed_module_enabled() {
  as_www php -r '$c = require "app/etc/config.php"; exit(empty($c["modules"]["MyParcelNL_DevSeed"]) ? 1 : 0);'
}

# A code sync restores config.php from the image, so this runs on every start.
disable_seed_module() {
  if [ "$WITH_SEED" != 1 ] && seed_module_enabled; then
    magento module:disable MyParcelNL_DevSeed
  fi
}

opensearch_host() {
  # Magento takes the scheme from the host name and uses http without one
  if [ "$OPENSEARCH_SCHEME" = https ]; then
    printf 'https://%s' "$OPENSEARCH_HOST"
  else
    printf '%s' "$OPENSEARCH_HOST"
  fi
}

# The same modules that the image build disables. config.php of the image already has them disabled.
disabled_modules() {
  local braintree
  braintree="$(as_www /usr/local/lib/magento-scripts/build/braintree-modules.sh | paste -sd, -)"
  printf 'Magento_TwoFactorAuth,Magento_AdminAdobeImsTwoFactorAuth%s' "${braintree:+,$braintree}"
}

install_magento() {
  local args=(
    --db-host="$DB_HOST:$DB_PORT"
    --db-name="$DB_NAME"
    --db-user="$DB_USER"
    --db-password="$DB_PASSWORD"
    --search-engine=opensearch
    --opensearch-host="$(opensearch_host)"
    --opensearch-port="$OPENSEARCH_PORT"
    --opensearch-index-prefix="$OPENSEARCH_INDEX_PREFIX"
    --base-url="$FULL_URL/"
    --use-rewrites=1
    --backend-frontname=admin
    --admin-user="$ADMIN_USER"
    --admin-password="$ADMIN_PASSWORD"
    --admin-email=admin@example.com
    --admin-firstname=Admin
    --admin-lastname=MyParcel
    --language=en_US
    --currency=EUR
    --timezone=Europe/Amsterdam
    --disable-modules="$(disabled_modules)"
  )

  if [ -n "$OPENSEARCH_USER" ]; then
    args+=(--opensearch-enable-auth=1 --opensearch-username="$OPENSEARCH_USER" --opensearch-password="$OPENSEARCH_PASSWORD")
  fi
  if [ -n "$MAGENTO_CRYPT_KEY" ]; then
    args+=(--key="$MAGENTO_CRYPT_KEY")
  fi

  magento setup:install "${args[@]}"
  apply_admin_settings
  seed_orders
  # Last: without it, the next start stops instead of reporting a half-installed shop as ready
  set_config "$INSTALL_MARKER" 1
}

# Stops the start when the query fails: a read error must not look like an unfinished install.
install_is_complete() {
  local marker
  marker="$(db_query "SELECT value FROM core_config_data WHERE scope = 'default' AND scope_id = 0 AND path = '$INSTALL_MARKER'")" \
    || fail "Cannot read the install marker from the database $DB_NAME on $DB_HOST"
  [ "$marker" = 1 ]
}

apply_admin_settings() {
  set_config admin/captcha/enable 0
  set_config customer/captcha/enable 0
  set_config admin/security/password_is_forced 0
  set_config admin/security/password_lifetime 0
  set_config admin/security/session_lifetime 86400
}

seed_orders() {
  local commands

  [ "$WITH_SEED" = 1 ] || return 0
  commands="$(as_www php bin/magento list --raw)"
  if grep -q '^myparcel:seed:orders ' <<<"$commands"; then
    magento myparcel:seed:orders --count=200
  fi
}

# The database survived, env.php did not (for example a new volume on AWS).
restore_env_php() {
  [ -n "$MAGENTO_CRYPT_KEY" ] \
    || fail "Database is installed but app/etc/env.php is missing: set MAGENTO_CRYPT_KEY or reset the database"

  magento setup:config:set --no-interaction \
    --db-host="$DB_HOST:$DB_PORT" \
    --db-name="$DB_NAME" \
    --db-user="$DB_USER" \
    --db-password="$DB_PASSWORD" \
    --backend-frontname=admin \
    --session-save=files \
    --document-root-is-pub=true \
    --key="$MAGENTO_CRYPT_KEY"
  # setup:config:set writes no install date, and Magento counts the shop as not installed without one
  as_www php -r '
    require "app/bootstrap.php";
    \Magento\Framework\App\Bootstrap::create(BP, $_SERVER)->getObjectManager()
      ->get(\Magento\Framework\App\DeploymentConfig\Writer::class)
      ->saveConfig([\Magento\Framework\Config\File\ConfigFilePool::APP_ENV => ["install" => ["date" => date("r")]]]);'
  magento cache:enable
}

upgrade_magento() {
  if ! as_www php bin/magento setup:db:status >/dev/null; then
    magento setup:upgrade --keep-generated
    UPGRADED=1
  fi
}

set_deploy_mode() {
  local current
  current="$(as_www php bin/magento deploy:mode:show)"

  if ! grep -q "mode: $MAGENTO_MODE\." <<<"$current"; then
    magento deploy:mode:set "$MAGENTO_MODE" --skip-compilation
  fi
}

# The sync brings the compiled DI and static files of the image. Magento uses compiled DI when it exists,
# also in developer mode, and deploy:mode:set does not run when the mode stays the same.
remove_compiled_files() {
  find generated/code generated/metadata pub/static -mindepth 1 -maxdepth 1 ! -path pub/static/.htaccess \
    -exec rm -rf {} + 2>/dev/null || true
}

clean_developer_files() {
  [ "$MAGENTO_MODE" = developer ] && [ "$CODE_SYNCED" = 1 ] || return 0

  log "Removing the compiled files of the image (developer mode)"
  remove_compiled_files
}

# Module changes, setup:upgrade without --keep-generated and developer mode remove the compiled files.
compile_when_missing() {
  [ "$MAGENTO_MODE" = production ] || return 0

  if [ ! -e generated/metadata/global.php ]; then
    magento setup:di:compile
  fi
  if [ ! -e pub/static/deployed_version.txt ]; then
    log "> static content deploy"
    as_www /usr/local/lib/magento-scripts/build/static-content-deploy.sh
  fi
}

set_base_urls() {
  local secure=0
  [[ "$FULL_URL" == https://* ]] && secure=1

  set_config web/unsecure/base_url "$FULL_URL/"
  set_config web/secure/base_url "$FULL_URL/"
  set_config web/secure/use_in_frontend "$secure"
  set_config web/secure/use_in_adminhtml "$secure"
}
