#!/usr/bin/env bash
# Smoke tests for the Magento image.
#   smoke.sh build <magento> <php>   Build the image and check its contents.
#   smoke.sh run <magento> <php>     Start the built image in tests/compose.yml and check the start sequence.
#                                    WEB_PORT (8080) sets the web port; SMOKE_KEEP=1 keeps the stack afterwards.
#                                    PLUGIN_CHECKOUT: plugin checkout for the local checkout check (default: a fresh clone).
#                                    Without vendor/, the smoke runs composer install in it.
#                                    WITH_SEED=0 starts without the seed module and skips the seed and plugin mode checks.
#   smoke.sh labels <image>          Print the plugin and SDK version labels of an image, one key=value per line.
set -euo pipefail

IMAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS_FILE="$IMAGE_DIR/versions.json"
FIXTURES="$IMAGE_DIR/seed/fixtures"
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/myparcelnl/magento}"

failures=0

pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

# Runs a bash snippet in the image as www-data, in the Magento copy in /opt/magento, without the entrypoint.
in_image() {
  docker run --rm --entrypoint bash --user www-data --workdir /opt/magento "$1" -c "$2"
}

check() {
  local name="$1" image="$2" snippet="$3"

  if in_image "$image" "$snippet" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi
}

# Prints a field of the versions.json entry for a Magento version.
matrix_value() {
  jq -r --arg m "$1" ".[] | select(.magento == \$m) | $2" "$VERSIONS_FILE"
}

# Prints the plugin and SDK versions that Composer installed as labels. A Dockerfile cannot set a label from a RUN result.
# build-magento.yml reads this output, so keep the format.
version_labels() {
  local image="$1" versions plugin sdk

  versions="$(in_image "$image" 'composer show --format=json myparcelnl/magento | jq -r .versions[0]; composer show --format=json myparcelnl/sdk | jq -r .versions[0]')"
  plugin="$(sed -n 1p <<<"$versions")$(in_image "$image" 'cat /usr/local/share/magento-image/plugin-version-suffix')"
  sdk="$(sed -n 2p <<<"$versions")"
  if [ -z "$plugin" ] || [ -z "$sdk" ]; then
    echo "Cannot read the plugin and SDK versions of $image" >&2
    return 1
  fi

  printf 'nl.myparcel.plugin.version=%s\nnl.myparcel.sdk.version=%s\n' "$plugin" "$sdk"
}

add_version_labels() {
  local image="$1" labels=() label

  while IFS= read -r label; do
    labels+=(--label "$label")
  done < <(version_labels "$image")

  echo "FROM $image" | docker build --quiet "${labels[@]}" --tag "$image" - >/dev/null
}

# Not `//`: it also replaces false. Fails when composer.json or the environment turns off the advisory block or the audit (Composer 2.10 "policy").
read -r -d '' COMPOSER_POLICY_ON <<'EOF2' || true
[ -z "${COMPOSER_NO_AUDIT:-}" ] && [ -z "${COMPOSER_NO_SECURITY_BLOCKING:-}" ] && jq -e '
  def at(p): try getpath(p) catch null;
  (.config // {}) as $c
  | ($c | at(["policy"])) != false
  and ($c | at(["policy", "advisories"])) != false
  and ($c | at(["policy", "advisories", "block"])) != false
  and (($c | at(["policy", "advisories", "audit"])) as $a | $a == null or $a == "fail")
  and ($c | at(["audit", "block-insecure"])) != false
  and (($c | at(["audit", "ignore"])) as $i | $i == null or $i == [])' composer.json
EOF2

cmd_build() {
  local magento="${1:?Usage: smoke.sh build <magento> <php>}" php="${2:?Usage: smoke.sh build <magento> <php>}"
  local image="$IMAGE_NAME:$magento-php$php" advisories scd_on_start start compose_env

  [ "$(matrix_value "$magento" ".php | index([\"$php\"]) != null")" = true ] \
    || { echo "Magento $magento with PHP $php is not in versions.json" >&2; exit 1; }
  advisories="$(matrix_value "$magento" '.accepted_advisories // [] | tojson')"
  scd_on_start="$(matrix_value "$magento" '.scd_on_start // false')"

  echo "Building $image"
  start=$SECONDS
  docker build \
    --build-arg "MAGENTO_VERSION=$magento" \
    --build-arg "PHP_VERSION=$php" \
    --build-arg "ACCEPTED_ADVISORIES=$advisories" \
    --build-arg "SCD_ON_START=$scd_on_start" \
    --tag "$image" \
    "$IMAGE_DIR"
  add_version_labels "$image"
  echo "Build took $((SECONDS - start)) s"

  echo "Checking $image"
  check "php -v shows PHP $php" "$image" "php -v | grep -q '^PHP ${php//./\\.}\\.'"
  check "bin/magento --version shows $magento" "$image" "bin/magento --version | grep -qF 'Magento CLI $magento'"
  check "myparcelnl/magento is installed" "$image" 'composer show myparcelnl/magento'
  check "no MyParcelNL psr-4 entry in composer.json" "$image" \
    'test "$(jq "[.autoload[\"psr-4\"] // {} | keys[] | select(test(\"MyParcelNL\"))] | length" composer.json)" = 0'
  check "generated code exists" "$image" 'test -d generated/code'
  if [ "$scd_on_start" = true ]; then
    echo "  SKIP  static content (scd_on_start in versions.json)"
  else
    check "static content for luma pl_PL and backend da_DK" "$image" \
      'test -d pub/static/frontend/Magento/luma/pl_PL && test -d pub/static/adminhtml/Magento/backend/da_DK'
  fi
  check "no app/etc/env.php" "$image" 'test ! -e app/etc/env.php'
  check "no PayPal Braintree module is enabled" "$image" \
    '! bin/magento module:status | sed -n "/List of enabled modules/,/List of disabled modules/p" | grep -q "^PayPal_Braintree"'
  check "image ID marker in /opt/magento/.image-id" "$image" 'test -s .image-id'
  check "/var/www/html is empty" "$image" 'test -z "$(ls -A /var/www/html)"'
  check "php-fpm -t passes and listens on 0.0.0.0:9000" "$image" \
    'php-fpm -t && php-fpm -tt 2>&1 | grep -q "listen = 0.0.0.0:9000"'
  check "Composer accepts only the advisories in versions.json" "$image" \
    "test \"\$(jq -c '.config.policy.advisories[\"ignore-id\"] // []' composer.json)\" = '$advisories'"
  check "Composer audit and advisory blocking are on" "$image" "$COMPOSER_POLICY_ON"
  check "no repo.magento.com in auth.json or composer.json" "$image" \
    '! grep -qri "repo.magento.com" auth.json composer.json 2>/dev/null'
  if docker image inspect --format '{{ index .Config.Labels "nl.myparcel.plugin.version" }} {{ index .Config.Labels "nl.myparcel.sdk.version" }}' "$image" \
    | grep -qE '^[0-9][^ ]* [0-9][^ ]*$'; then
    pass "plugin and SDK version labels"
  else
    fail "plugin and SDK version labels"
  fi

  compose_env=(IMAGE="$image" MARIADB_VERSION="$(matrix_value "$magento" .mariadb)" OPENSEARCH_VERSION="$(matrix_value "$magento" .opensearch)")
  if env "${compose_env[@]}" docker compose -f "$IMAGE_DIR/tests/compose.yml" config --quiet; then
    pass "tests/compose.yml is valid"
  else
    fail "tests/compose.yml is valid"
  fi

  docker image inspect --format 'Labels: {{ json .Config.Labels }}' "$image"
  docker image ls --format 'Size: {{ .Size }}' "$image"

  if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed"
    exit 1
  fi
  echo "All checks passed"
}

# Runs docker compose for the test stack of the current pair. Needs COMPOSE_ENV and PROJECT.
STACK_FILES=()

stack() {
  env "${COMPOSE_ENV[@]}" docker compose -p "$PROJECT" -f "$IMAGE_DIR/tests/compose.yml" ${STACK_FILES[@]+"${STACK_FILES[@]}"} "$@"
}

# Waits until the php container printed the ready line after the given time, or stopped.
wait_ready() {
  local since="$1" timeout="${2:-1200}" start=$SECONDS id

  while [ $((SECONDS - start)) -lt "$timeout" ]; do
    id="$(stack ps -a -q php)"
    if [ -n "$id" ]; then
      grep -q 'Magento is ready at ' <<<"$(docker logs --since "$since" "$id" 2>&1)" && return 0
      [ "$(docker inspect -f '{{.State.Status}}' "$id")" = exited ] && break
    fi
    sleep 5
  done
  echo "php did not print the ready line; last log lines:" >&2
  [ -n "$id" ] && docker logs --tail 30 "$id" >&2
  return 1
}

php_logs_since() {
  docker logs --since "$1" "$(stack ps -a -q php)" 2>&1
}

in_php() {
  stack exec -T --user www-data php bash -c "$1"
}

config_value() {
  stack exec -T db mariadb -umagento -pmagento magento -N -e \
    "SELECT value FROM core_config_data WHERE scope = 'default' AND scope_id = 0 AND path = '$1'"
}

expect() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi
}

http_ok() {
  [ "$(curl -sS -o /dev/null -w '%{http_code}' "$1")" = 200 ]
}

config_is() {
  [ "$(config_value "$1")" = "$2" ]
}

db_value() {
  stack exec -T db mariadb -umagento -pmagento magento -N -e "$1"
}

db_is() {
  [ "$(db_value "$1")" = "$2" ]
}

db_at_least() {
  [ "$(db_value "$1")" -ge "$2" ]
}

# Checks the effective config value of a store view: store scope, else website scope, else default scope.
# bin/magento config:show --scope=stores shows only a value set on the store scope itself.
store_config_is() {
  [ "$(db_value "SELECT COALESCE(
      (SELECT c.value FROM core_config_data c WHERE c.scope = 'stores' AND c.scope_id = s.store_id AND c.path = '$2'),
      (SELECT c.value FROM core_config_data c WHERE c.scope = 'websites' AND c.scope_id = s.website_id AND c.path = '$2'),
      (SELECT c.value FROM core_config_data c WHERE c.scope = 'default' AND c.scope_id = 0 AND c.path = '$2'))
    FROM store s WHERE s.code = '$1'")" = "$3" ]
}

# Takes store:locale pairs.
store_locales_are() {
  local pair
  for pair in "$@"; do
    store_config_is "${pair%%:*}" general/locale/code "${pair#*:}" || return 1
  done
}

matrix_has_rules() {
  [ "$(config_value myparcelnl_magento_general/matrix/delivery_costs | jq length)" = "$1" ]
}

# Gets a customer token through the storefront REST API. Does not print the token.
customer_login_works() {
  local body
  body="$(jq -c '.[0] | {username: .email, password: .password}' "$FIXTURES/customers.json")"
  curl -sS -X POST -H 'Content-Type: application/json' -d "$body" "$1/rest/nl/V1/integration/customer/token" \
    | grep -qE '^"[A-Za-z0-9._-]+"$'
}

# Checks the data that the seed patches of MyParcelNL_DevSeed create.
seed_checks() {
  local url="$1" products store

  products="$(jq length "$FIXTURES/products.json")"

  expect "website codes are admin nl be it" \
    db_is "SELECT GROUP_CONCAT(code ORDER BY website_id SEPARATOR ' ') FROM store_website" 'admin nl be it'
  expect "store codes are admin nl be_nl be_fr it" \
    db_is "SELECT GROUP_CONCAT(code ORDER BY store_id SEPARATOR ' ') FROM store" 'admin nl be_nl be_fr it'
  for store in nl be_nl be_fr it; do
    expect "GET /$store/ returns 200" http_ok "$url/$store/"
  done
  expect "locale per store is nl_NL nl_NL fr_FR it_IT" store_locales_are nl:nl_NL be_nl:nl_NL be_fr:fr_FR it:it_IT
  expect "$products products, one per SKU" \
    db_is "SELECT COUNT(*), COUNT(DISTINCT sku) FROM catalog_product_entity" "$products	$products"
  expect "every product is in all three websites" \
    db_is "SELECT COUNT(*) FROM (SELECT product_id FROM catalog_product_website GROUP BY product_id HAVING COUNT(*) = 3) p" "$products"
  expect "delivery costs matrix has 9 rules" matrix_has_rules 9
  expect "carriers/freeshipping/active = 1" config_is carriers/freeshipping/active 1
  expect "carriers/freeshipping/free_shipping_subtotal = 100" config_is carriers/freeshipping/free_shipping_subtotal 100
  expect "carriers/freeshipping/tax_including = 1" config_is carriers/freeshipping/tax_including 1
  expect "carriers/myparcel/shipping_cost = 24.95" config_is carriers/myparcel/shipping_cost 24.95
  expect "PostNL mailbox is on" config_is myparcelnl_magento_postnl_settings/mailbox/active 1
  expect "PostNL digital stamp is on" config_is myparcelnl_magento_postnl_settings/digital_stamp/active 1
  expect "no delivery date key in DE, FR, IT and US orders" db_is \
    "SELECT COUNT(*) FROM sales_order o JOIN sales_order_address a ON a.parent_id = o.entity_id AND a.address_type = 'shipping'
     WHERE a.country_id NOT IN ('NL', 'BE') AND o.myparcel_delivery_options LIKE '%\"date\"%'" 0
  expect "3 customers with 18 addresses each" db_is \
    "SELECT COUNT(*), (SELECT COUNT(*) FROM (SELECT parent_id FROM customer_address_entity GROUP BY parent_id HAVING COUNT(*) = 18) a) FROM customer_entity" \
    "3	3"
  expect "every BE, IT and US address has a region" \
    db_is "SELECT COUNT(*) FROM customer_address_entity WHERE country_id IN ('BE', 'IT', 'US') AND region_id IS NULL" 0
  expect "storefront login of the first customer works" customer_login_works "$url"
  order_checks
}

# Checks the orders of myparcel:seed:orders.
order_checks() {
  expect "200 seed orders" db_is "SELECT COUNT(*) FROM sales_order" 200
  expect "at least 150 MyParcel orders with delivery options" db_at_least \
    "SELECT COUNT(*) FROM sales_order WHERE shipping_method = 'myparcel_myparcel' AND myparcel_delivery_options LIKE '{%'" 150
  expect "no pickup orders" db_is "SELECT COUNT(*) FROM sales_order WHERE myparcel_delivery_options LIKE '%\"isPickup\":true%'" 0
  expect "no complete MyParcel orders" \
    db_is "SELECT COUNT(*) FROM sales_order WHERE shipping_method = 'myparcel_myparcel' AND state = 'complete'" 0
  expect "orders are pending, processing and complete" db_is \
    "SELECT GROUP_CONCAT(DISTINCT status ORDER BY status SEPARATOR ' ') FROM sales_order" 'complete pending processing'
  expect "order dates are within the last 30 days" db_is \
    "SELECT COUNT(*) FROM sales_order_grid WHERE created_at < UTC_TIMESTAMP() - INTERVAL 30 DAY OR created_at > UTC_TIMESTAMP()" 0
  expect "no order email sent" db_is "SELECT COUNT(*) FROM sales_order WHERE email_sent = 1 OR send_email = 1" 0
  grep -o 'Created [0-9]* seed orders in [0-9]* s' <<<"$(php_logs_since "$SINCE_FIRST_START")" | sed 's/^/  /'
}

# Logs in to the admin and prints Stores > Configuration. Follows the menu link, because admin URLs carry a secret key.
admin_config_page() {
  local url="$1" jar page key config

  jar="$(mktemp "$SMOKE_TMP/cookies.XXXXXX")"
  page="$(curl -sS -c "$jar" -b "$jar" "$url/admin/")"
  key="$(grep -oE 'name="form_key"[^>]*value="[^"]*"' <<<"$page" | head -1 | sed 's/.*value="//; s/"$//')"
  [ -n "$key" ] || return 1
  page="$(curl -sS -L -c "$jar" -b "$jar" --data-urlencode "form_key=$key" \
    --data-urlencode 'login[username]=admin' --data-urlencode 'login[password]=admin123' "$url/admin/")"
  config="$(grep -oE 'href="[^"]*/admin/system_config/[^"]*"' <<<"$page" | head -1 | sed 's/^href="//; s/"$//')"
  [ -n "$config" ] || return 1
  curl -sS -L -c "$jar" -b "$jar" "$config"
}

# Braintree's system.js needs Prototype.js, which the admin no longer loads, and breaks the JS of every config page.
config_page_without_braintree() {
  local page
  page="$(admin_config_page "$1")" || return 1
  grep -q 'id="config-edit-form"' <<<"$page" && ! grep -q 'PayPal_Braintree/js/system' <<<"$page"
}

no_install_since() {
  ! grep -q 'setup:install' <<<"$(php_logs_since "$1")"
}

log_has_since() {
  grep -q "$2" <<<"$(php_logs_since "$1")"
}

# Waits up to 180 s until the php container stopped. Prints its exit code.
wait_exit() {
  local id start=$SECONDS
  id="$(stack ps -a -q php)"
  while [ "$(docker inspect -f '{{.State.Status}}' "$id")" != exited ] && [ $((SECONDS - start)) -lt 180 ]; do
    sleep 3
  done
  docker inspect -f '{{.State.Status}} {{.State.ExitCode}}' "$id"
}

package_version_is() {
  [ "$(in_php "composer show --format=json $1 | jq -r '.versions[0]'")" = "$2" ]
}

plugin_link_is() {
  [ "$(in_php 'readlink -f vendor/myparcelnl/magento')" = "$1" ] && in_php 'test ! -e app/code/MyParcelNL'
}

# Sets CHECKOUT to a plugin checkout with its own vendor/, as a developer has it for PhpStorm.
prepare_checkout() {
  CHECKOUT="${PLUGIN_CHECKOUT:-$SMOKE_TMP/magento}"

  if [ ! -d "$CHECKOUT" ]; then
    git clone -q --depth 1 https://github.com/myparcelnl/magento "$CHECKOUT" || return 1
  fi
  if [ ! -d "$CHECKOUT/vendor" ]; then
    docker run --rm --user "$(id -u):$(id -g)" -e COMPOSER_HOME=/tmp/composer -v "$CHECKOUT:/checkout" -w /checkout \
      --entrypoint composer "$1" install --no-progress --quiet || return 1
  fi
}

# Writes a compose file that mounts CHECKOUT at /var/www/html/plugins/<name> in php and web.
# compose.yml has a vendor/ tmpfs only for the default names (magento, sdk, hyva-checkout).
checkout_compose_file() {
  local file="$SMOKE_TMP/checkout-$1.yml"

  printf 'services:\n  php:\n    volumes:\n      - %s:/var/www/html/plugins/%s\n  web:\n    volumes:\n      - %s:/var/www/html/plugins/%s:ro\n' \
    "$CHECKOUT" "$1" "$CHECKOUT" "$1" > "$file"
  printf '%s' "$file"
}

# Without a checkout, the vendor/ tmpfs leaves empty folders in plugins/. They must not look like a checkout.
release_without_checkout() {
  in_php 'test -d plugins/magento/vendor && test ! -e plugins/magento/composer.json && test ! -e .plugin-modes-applied' \
    && package_version_is myparcelnl/magento "$1" && ! log_has_since "$SINCE_FIRST_START" 'Using the checkout'
}

# Files of the checkout on the host. vendor/ is a tmpfs in php, so the sync cannot reach it.
checkout_file_count() {
  find "$CHECKOUT" -path "$CHECKOUT/vendor" -prune -o -type f -print | wc -l | tr -d ' '
}

plugin_mode_checks() {
  local image="$1" url="http://localhost:$2" release since start state id files

  release="$(docker image inspect --format '{{ index .Config.Labels "nl.myparcel.plugin.version" }}' "$image")"
  release="${release%%+*}"

  expect "empty plugins/<name>/vendor folders keep the release" release_without_checkout "$release"

  prepare_checkout "$image" || echo "  Could not prepare the plugin checkout" >&2
  stack down -v --remove-orphans >/dev/null 2>&1
  STACK_FILES=(-f "$(checkout_compose_file magento)")
  COMPOSE_ENV=("${BASE_ENV[@]}" PLUGIN_VERSION=dev-main)
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  start=$SECONDS
  stack up -d --wait --wait-timeout 1200 >/dev/null 2>&1 || true
  if wait_ready "$since" 60 && package_version_is myparcelnl/magento dev-main && http_ok "$url/nl/"; then
    pass "branch mode"
  else
    fail "branch mode"
  fi
  expect "PLUGIN_VERSION wins over a mounted checkout" \
    log_has_since "$since" 'The checkout in /var/www/html/plugins/magento is not used, because PLUGIN_VERSION is set'
  echo "  Branch mode first start took $((SECONDS - start)) s (release: $FIRST_START_TIME s)"

  STACK_FILES=()
  COMPOSE_ENV=("${BASE_ENV[@]}")
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  start=$SECONDS
  stack up -d --wait --wait-timeout 1200 >/dev/null 2>&1 || true
  if wait_ready "$since" 60 && package_version_is myparcelnl/magento "$release" && http_ok "$url/nl/"; then
    pass "back to release ($release)"
  else
    fail "back to release ($release)"
  fi
  echo "  Back to release took $((SECONDS - start)) s"

  STACK_FILES=(-f "$(checkout_compose_file custom)")
  COMPOSE_ENV=("${BASE_ENV[@]}" PLUGIN_PATH=/var/www/html/plugins/custom)
  stack stop php >/dev/null 2>&1
  start=$SECONDS
  id="$(stack run -d --no-deps php)"
  while [ "$(docker inspect -f '{{.State.Status}}' "$id")" != exited ] && [ $((SECONDS - start)) -lt 600 ]; do
    sleep 5
  done
  state="$(docker inspect -f '{{.State.Status}} {{.State.ExitCode}}' "$id")"
  if [ "${state% *}" = exited ] && [ "$state" != "exited 0" ] \
    && grep -q '/var/www/html/plugins/custom/vendor is not empty' <<<"$(docker logs "$id" 2>&1)"; then
    pass "custom checkout path without a vendor/ tmpfs stops the start"
  else
    fail "custom checkout path without a vendor/ tmpfs stops the start ($state)"
  fi
  echo "  Local checkout up to the vendor/ check took $((SECONDS - start)) s"
  docker rm -f "$id" >/dev/null

  STACK_FILES=(-f "$(checkout_compose_file magento)")
  COMPOSE_ENV=("${BASE_ENV[@]}")
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  start=$SECONDS
  stack up -d --wait --wait-timeout 1200 >/dev/null 2>&1 || true
  if wait_ready "$since" 60 && log_has_since "$since" 'Using the checkout in /var/www/html/plugins/magento (PLUGIN_PATH)' \
    && plugin_link_is /var/www/html/plugins/magento && http_ok "$url/nl/"; then
    pass "local checkout is found without PLUGIN_PATH"
  else
    fail "local checkout is found without PLUGIN_PATH"
  fi
  if [ -d "$CHECKOUT/vendor/magento/framework" ] && in_php 'test -e generated/metadata/global.php' \
    && in_php 'bin/magento deploy:mode:show | grep -q production' && http_ok "$url/nl/"; then
    pass "local checkout with its own vendor/ compiles in production mode"
  else
    fail "local checkout with its own vendor/ compiles in production mode"
  fi
  echo "  Local checkout compile and start took $((SECONDS - start)) s"

  files="$(checkout_file_count)"
  stack exec -T php bash -c 'echo smoke-old-image > .image-id'
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  stack restart php >/dev/null
  if wait_ready "$since" && log_has_since "$since" 'Syncing the code of image' \
    && [ "$files" -gt 0 ] && [ "$(checkout_file_count)" = "$files" ]; then
    pass "image update keeps the files of the local checkout ($files)"
  else
    fail "image update keeps the files of the local checkout ($files before, $(checkout_file_count) after)"
  fi

  STACK_FILES=()
  COMPOSE_ENV=("${BASE_ENV[@]}")
  stack stop php >/dev/null 2>&1
  start=$SECONDS
  id="$(stack run -d --no-deps -e PLUGIN_VERSION=dev-does-not-exist php)"
  while [ "$(docker inspect -f '{{.State.Status}}' "$id")" != exited ] && [ $((SECONDS - start)) -lt 300 ]; do
    sleep 5
  done
  state="$(docker inspect -f '{{.State.Status}} {{.State.ExitCode}}' "$id")"
  if [ "${state% *}" = exited ] && [ "$state" != "exited 0" ] \
    && grep -q 'Composer could not install myparcelnl/magento:dev-does-not-exist' <<<"$(docker logs "$id" 2>&1)"; then
    pass "bad branch fails"
  else
    fail "bad branch fails ($state)"
  fi
  echo "  Bad branch took $((SECONDS - start)) s"
  docker logs --tail 3 "$id"
  docker rm -f "$id" >/dev/null

  COMPOSE_ENV=("${BASE_ENV[@]}" WITH_HYVA=1)
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  stack up -d --wait --wait-timeout 1200 >/dev/null 2>&1 || true
  if wait_ready "$since" 60 && log_has_since "$since" 'Hyvä add-on is not available yet' \
    && package_version_is myparcelnl/magento "$release" && http_ok "$url/nl/"; then
    pass "hyva hook"
  else
    fail "hyva hook"
  fi
}

cmd_run() {
  local magento="${1:?Usage: smoke.sh run <magento> <php>}" php="${2:?Usage: smoke.sh run <magento> <php>}"
  local image="$IMAGE_NAME:$magento-php$php" port="${WEB_PORT:-8080}" since start id env_sum state
  local with_seed="${WITH_SEED:-1}" orders=0

  # Without the seed module there are no orders
  [ "$with_seed" = 1 ] && orders=200

  PROJECT="magento-smoke-$(tr -c 'a-z0-9' '-' <<<"$magento-$php" | sed 's/-*$//')"
  BASE_ENV=(IMAGE="$image" WEB_PORT="$port" FULL_URL="http://localhost:$port" WITH_SEED="$with_seed"
    MARIADB_VERSION="$(matrix_value "$magento" .mariadb)" OPENSEARCH_VERSION="$(matrix_value "$magento" .opensearch)")
  COMPOSE_ENV=("${BASE_ENV[@]}")
  SMOKE_TMP="$(mktemp -d)"
  if [ "${SMOKE_KEEP:-0}" = 1 ]; then
    trap 'rm -rf "$SMOKE_TMP"' EXIT
  else
    trap 'stack down -v --remove-orphans >/dev/null 2>&1; rm -rf "$SMOKE_TMP"' EXIT
  fi

  stack down -v --remove-orphans >/dev/null 2>&1
  echo "Starting $image as project $PROJECT on port $port"
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  SINCE_FIRST_START="$since"
  start=$SECONDS
  stack up -d --wait --wait-timeout 1200 || true
  if wait_ready "$since" 60; then
    pass "first start prints the ready line"
    FIRST_START_TIME=$((SECONDS - start))
    echo "  First start took $FIRST_START_TIME s"
  else
    fail "first start prints the ready line"
    echo "$failures check(s) failed"
    exit 1
  fi

  expect "GET / returns 200" http_ok "http://localhost:$port/"
  expect "GET /admin/ returns 200" http_ok "http://localhost:$port/admin/"
  expect "deploy mode is production" in_php 'bin/magento deploy:mode:show | grep -q production'
  expect "Magento_TwoFactorAuth is disabled" in_php 'bin/magento module:status Magento_TwoFactorAuth | grep -q "Module is disabled"'
  expect "PayPal_Braintree is disabled" in_php 'bin/magento module:status PayPal_Braintree | grep -q "Module is disabled"'
  expect "admin config page has the form and no Braintree system.js" config_page_without_braintree "http://localhost:$port"
  if [ "$with_seed" = 1 ]; then
    expect "MyParcelNL_DevSeed is enabled (WITH_SEED=1)" in_php 'bin/magento module:status MyParcelNL_DevSeed | grep -q "Module is enabled"'
  else
    expect "MyParcelNL_DevSeed is disabled (WITH_SEED=$with_seed)" in_php 'bin/magento module:status MyParcelNL_DevSeed | grep -q "Module is disabled"'
  fi
  expect "admin/captcha/enable = 0" config_is admin/captcha/enable 0
  expect "customer/captcha/enable = 0" config_is customer/captcha/enable 0
  expect "admin/security/password_is_forced = 0" config_is admin/security/password_is_forced 0
  expect "admin/security/password_lifetime = 0" config_is admin/security/password_lifetime 0
  expect "admin/security/session_lifetime = 86400" config_is admin/security/session_lifetime 86400
  expect "install marker is set" config_is dev/myparcel_image/install_complete 1
  if [ "$with_seed" = 1 ]; then
    seed_checks "http://localhost:$port"
  else
    expect "no orders" db_is "SELECT COUNT(*) FROM sales_order" 0
  fi

  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  start=$SECONDS
  stack restart php >/dev/null
  if wait_ready "$since" && no_install_since "$since" && db_is "SELECT COUNT(*) FROM sales_order" "$orders"; then
    pass "restart keeps state"
  else
    fail "restart keeps state"
  fi
  echo "  Restart took $((SECONDS - start)) s"

  stack down >/dev/null 2>&1
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  start=$SECONDS
  stack up -d --wait --wait-timeout 1200 >/dev/null 2>&1 || true
  if wait_ready "$since" 60 && no_install_since "$since" && http_ok "http://localhost:$port/" \
    && db_is "SELECT COUNT(*) FROM sales_order" "$orders"; then
    pass "recreate keeps state"
  else
    fail "recreate keeps state"
  fi
  echo "  Recreate took $((SECONDS - start)) s"

  stack exec -T php bash -c 'touch vendor/smoke-marker && echo smoke-old-image > .image-id'
  env_sum="$(stack exec -T php md5sum app/etc/env.php)"
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  start=$SECONDS
  stack restart php >/dev/null
  if wait_ready "$since" \
    && stack exec -T php bash -c 'test ! -e vendor/smoke-marker && cmp -s .image-id /opt/magento/.image-id' \
    && [ "$(stack exec -T php md5sum app/etc/env.php)" = "$env_sum" ] \
    && http_ok "http://localhost:$port/"; then
    pass "image update syncs code"
  else
    fail "image update syncs code"
  fi
  echo "  Start after image update took $((SECONDS - start)) s"
  expect "image update flushes the cache" log_has_since "$since" 'bin/magento cache:flush'
  if [ "$with_seed" != 1 ]; then
    # The sync brings config.php of the image, with the seed module enabled
    expect "image update disables the seed module again" log_has_since "$since" 'bin/magento module:disable'
    expect "image update compiles DI again" in_php 'test -e generated/metadata/global.php'
    expect "MyParcelNL_DevSeed stays disabled" in_php 'bin/magento module:status MyParcelNL_DevSeed | grep -q "Module is disabled"'
  fi

  COMPOSE_ENV+=(FULL_URL="http://127.0.0.1:$port")
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  stack up -d --wait --wait-timeout 1200 >/dev/null 2>&1 || true
  if wait_ready "$since" 60 \
    && config_is web/unsecure/base_url "http://127.0.0.1:$port/" \
    && config_is web/secure/base_url "http://127.0.0.1:$port/" \
    && http_ok "http://127.0.0.1:$port/"; then
    pass "new FULL_URL"
  else
    fail "new FULL_URL"
  fi

  stack exec -T db mariadb -umagento -pmagento magento -e \
    "DELETE FROM core_config_data WHERE path = 'dev/myparcel_image/install_complete'"
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  stack restart php >/dev/null
  state="$(wait_exit)"
  if [ "$state" = "exited 1" ] && log_has_since "$since" 'A previous install did not finish'; then
    pass "unfinished install stops the start"
  else
    fail "unfinished install stops the start ($state)"
  fi
  stack exec -T db mariadb -umagento -pmagento magento -e \
    "INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('default', 0, 'dev/myparcel_image/install_complete', '1')"

  COMPOSE_ENV+=(MAGENTO_MODE=developer)
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  stack up -d --wait --wait-timeout 1200 >/dev/null 2>&1 || true
  wait_ready "$since" 60 >/dev/null 2>&1 || true
  stack exec -T php bash -c 'echo smoke-old-image > .image-id'
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  stack restart php >/dev/null
  if wait_ready "$since" \
    && ! log_has_since "$since" 'deploy:mode:set' \
    && stack exec -T php bash -c 'test ! -e generated/metadata/global.php && test -z "$(ls pub/static)" && test -e pub/static/.htaccess'; then
    pass "image update in developer mode removes the compiled files"
  else
    fail "image update in developer mode removes the compiled files"
  fi

  start=$SECONDS
  id="$(stack run -d --no-deps -e OPENSEARCH_HOST=does-not-exist php)"
  while [ "$(docker inspect -f '{{.State.Status}}' "$id")" != exited ] && [ $((SECONDS - start)) -lt 300 ]; do
    sleep 5
  done
  if [ "$(docker inspect -f '{{.State.Status}} {{.State.ExitCode}}' "$id")" != "exited 0" ] \
    && [ "$(docker inspect -f '{{.State.Status}}' "$id")" = exited ] \
    && grep -q OpenSearch <<<"$(docker logs "$id" 2>&1)" \
    && grep -q memory <<<"$(docker logs "$id" 2>&1)"; then
    pass "search timeout stops the start"
  else
    fail "search timeout stops the start"
  fi
  echo "  Search timeout took $((SECONDS - start)) s"
  docker logs --tail 2 "$id"
  docker rm -f "$id" >/dev/null

  # The plugin mode checks open /nl/, a store view of the seed module
  if [ "$with_seed" = 1 ]; then
    plugin_mode_checks "$image" "$port"
  else
    echo "  SKIP  plugin mode checks (WITH_SEED=$with_seed)"
  fi

  if [ "$failures" -gt 0 ]; then
    echo "$failures check(s) failed"
    exit 1
  fi
  echo "All checks passed"
}

case "${1:-}" in
  build) shift; cmd_build "$@" ;;
  run) shift; cmd_run "$@" ;;
  labels) shift; version_labels "${1:?Usage: smoke.sh labels <image>}" ;;
  *) echo "Usage: smoke.sh build|run <magento> <php> | smoke.sh labels <image>" >&2; exit 2 ;;
esac
