#!/usr/bin/env bash
# Start sequence of the php container: wait for the services, sync the code, install or upgrade
# Magento, set the base URLs and the deploy mode, then run php-fpm in the foreground.
set -euo pipefail

: "${BASE_URL:=localhost}"
: "${FULL_URL:=https://$BASE_URL}"
: "${MAGENTO_MODE:=production}"
: "${ADMIN_USER:=admin}"
: "${ADMIN_PASSWORD:=admin123}"
: "${WITH_SEED:=1}"
: "${WITH_HYVA:=0}"
: "${PLUGIN_VERSION:=}"
: "${SDK_VERSION:=}"
: "${PLUGIN_PATH:=}"
: "${SDK_PATH:=}"
: "${HYVA_MODULE_PATH:=}"
: "${DB_HOST:=db}"
: "${DB_PORT:=3306}"
: "${DB_NAME:=magento}"
: "${DB_USER:=magento}"
: "${DB_PASSWORD:=magento}"
: "${OPENSEARCH_HOST:=opensearch}"
: "${OPENSEARCH_PORT:=9200}"
: "${OPENSEARCH_SCHEME:=http}"
: "${OPENSEARCH_USER:=}"
: "${OPENSEARCH_PASSWORD:=}"
: "${OPENSEARCH_INDEX_PREFIX:=magento}"
: "${MAGENTO_CRYPT_KEY:=}"
: "${SMTP_HOST:=}"
FULL_URL="${FULL_URL%/}"
export BASE_URL FULL_URL MAGENTO_MODE WITH_SEED WITH_HYVA SMTP_HOST

case "$MAGENTO_MODE" in
  production | developer) ;;
  *) echo "[entrypoint] ERROR: MAGENTO_MODE must be production or developer, not '$MAGENTO_MODE'" >&2; exit 1 ;;
esac

scripts=/usr/local/lib/magento-scripts
# shellcheck source=_helpers.sh
. "$scripts/_helpers.sh"
# shellcheck source=_services.sh
. "$scripts/_services.sh"
# shellcheck source=_magento.sh
. "$scripts/_magento.sh"
. "$scripts/_composer-modes.sh"

ready_marker=/tmp/magento-ready
# The container file system survives a restart
rm -f "$ready_marker"
cd /var/www/html

wait_for_mariadb
wait_for_opensearch
sync_code
apply_plugin_modes
apply_hyva_hook
disable_seed_module

if ! database_is_installed; then
  install_magento
else
  install_is_complete \
    || fail "A previous install did not finish. Find the cause in the log of that start. To install again, remove the shop data: docker compose down -v"
  if [ ! -e app/etc/env.php ]; then
    restore_env_php
  fi
  upgrade_magento
  # var/ is not synced, so the cache still has config and pages of the old code. setup:upgrade flushes it.
  if { [ "$CODE_SYNCED" = 1 ] || [ "$PLUGIN_MODES_CHANGED" = 1 ]; } && [ "$UPGRADED" = 0 ]; then
    magento cache:flush
  fi
fi

set_base_urls
if [ "$CONFIG_CHANGED" = 1 ]; then
  magento cache:clean config full_page
fi
set_deploy_mode
clean_developer_files
check_checkout_vendors
compile_when_missing

touch "$ready_marker"
log "Magento is ready at $FULL_URL"
# Only the public default password goes in the log
if [ "$ADMIN_PASSWORD" = admin123 ]; then
  log "Admin: $FULL_URL/admin ($ADMIN_USER / $ADMIN_PASSWORD)"
else
  log "Admin: $FULL_URL/admin ($ADMIN_USER / the password in ADMIN_PASSWORD)"
fi
exec php-fpm -F
