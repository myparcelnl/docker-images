# Plugin modes: replace the release plugin, SDK or Hyvä module with a branch (VCS) or a mounted checkout (path).
# Each change starts from the release code of the image. The marker in the volume holds the applied hash.
PLUGIN_MODES_MARKER=/var/www/html/.plugin-modes-applied
PLUGIN_MODES_CHANGED=0
COMPOSER_PACKAGES=()

plugin_modes_hash() {
  [ -n "$PLUGIN_VERSION$SDK_VERSION$PLUGIN_PATH$SDK_PATH$HYVA_MODULE_PATH" ] || return 0
  printf '%s\n' "$PLUGIN_VERSION" "$SDK_VERSION" "$PLUGIN_PATH" "$SDK_PATH" "$HYVA_MODULE_PATH" | sha256sum | cut -d' ' -f1
}

restore_release_code() {
  log "Restoring the release code of the image"
  rm -f .image-id
  sync_code
}

# no-api: the GitHub API allows 60 requests per hour without a token, and these repositories have hundreds of tags.
add_vcs_package() {
  local name="$1" url="$2" package="$3" version="$4"

  as_www composer config "repositories.$name" "{\"type\":\"vcs\",\"url\":\"$url\",\"no-api\":true}"
  COMPOSER_PACKAGES+=("$package:$version")
}

# An optional 4th argument sets the package version, so that an exact requirement of the plugin matches.
add_path_package() {
  local name="$1" variable="$2" path="$3" version="${4:-}" package versions=""

  # Static content deploy reads module files relative to the Magento root, so a module outside it fails
  case "$(realpath -m "$path")" in
    /var/www/html/plugins/*) ;;
    *) fail "$variable=$path is outside /var/www/html/plugins: mount the checkout at /var/www/html/plugins/<name>" ;;
  esac
  [ -f "$path/composer.json" ] || fail "$variable=$path has no composer.json: mount the checkout at $path"
  package="$(jq -r .name "$path/composer.json")"
  [ -z "$version" ] || versions=",\"versions\":{\"$package\":\"$version\"}"
  as_www composer config "repositories.$name" "{\"type\":\"path\",\"url\":\"$path\",\"options\":{\"symlink\":true$versions}}"
  COMPOSER_PACKAGES+=("$package:@dev")
}

# The exact SDK version that the plugin requires, or nothing for a range or a plugin branch (not known before the install).
required_sdk_version() {
  local file=vendor/myparcelnl/magento/composer.json version

  [ -z "$PLUGIN_VERSION" ] || return 0
  [ -z "$PLUGIN_PATH" ] || file="$PLUGIN_PATH/composer.json"
  version="$(jq -r '.require["myparcelnl/sdk"] // empty' "$file" 2>/dev/null || true)"
  version="${version%@*}"
  if [[ "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    printf '%s' "$version"
  fi
}

# A branch gets an inline alias to the required version, unless the value already has one ("dev-x as 1.2.3").
sdk_constraint() {
  if [ -n "$1" ] && [[ "$SDK_VERSION" == dev-* ]] && [[ "$SDK_VERSION" != *" as "* ]]; then
    printf '%s as %s' "$SDK_VERSION" "$1"
  else
    printf '%s' "$SDK_VERSION"
  fi
}

# Uses a checkout at /var/www/html/plugins/<folder> when its *_PATH is empty. A set *_VERSION wins over the checkout.
# Detects on composer.json: the vendor/ tmpfs of docker-compose.yml makes empty folders when nothing is mounted.
detect_checkout() {
  local variable="$1" version_variable="$2" path="/var/www/html/plugins/$3"

  [ -z "${!variable}" ] || return 0
  if [ ! -f "$path/composer.json" ]; then
    # Only vendor/ (the tmpfs) means nothing is mounted. Other files mean a wrong source path.
    ls -A "$path" 2>/dev/null | grep -qvx vendor && log "WARNING: $path has no composer.json, so it is not used. Check the source path in docker-compose.override.yml"
    return 0
  fi
  if [ -n "$version_variable" ] && [ -n "${!version_variable}" ]; then
    log "The checkout in $path is not used, because $version_variable is set"
    return 0
  fi
  printf -v "$variable" '%s' "$path"
  log "Using the checkout in $path ($variable)"
}

apply_plugin_modes() {
  local wanted applied="" sdk_required hint=""

  detect_checkout PLUGIN_PATH PLUGIN_VERSION magento
  detect_checkout SDK_PATH SDK_VERSION sdk
  detect_checkout HYVA_MODULE_PATH "" hyva-checkout

  [ -z "$PLUGIN_VERSION" ] || [ -z "$PLUGIN_PATH" ] || fail "Set PLUGIN_VERSION or PLUGIN_PATH, not both"
  [ -z "$SDK_VERSION" ] || [ -z "$SDK_PATH" ] || fail "Set SDK_VERSION or SDK_PATH, not both"

  wanted="$(plugin_modes_hash)"
  [ -e "$PLUGIN_MODES_MARKER" ] && applied="$(cat "$PLUGIN_MODES_MARKER")"
  [ "$wanted" = "$applied" ] && return 0

  [ -z "$applied" ] || restore_release_code
  [ -n "$wanted" ] || return 0

  # Not a hash: after a failed Composer run, the next start restores the release code first
  echo pending > "$PLUGIN_MODES_MARKER"

  sdk_required="$(required_sdk_version)"
  if [ -n "$SDK_VERSION$SDK_PATH" ]; then
    hint=". The plugin requires myparcelnl/sdk ${sdk_required:-<see its composer.json>}; use SDK_VERSION=\"dev-<branch> as <that version>\""
  fi

  [ -z "$PLUGIN_VERSION" ] || add_vcs_package myparcel-magento https://github.com/myparcelnl/magento myparcelnl/magento "$PLUGIN_VERSION"
  [ -z "$SDK_VERSION" ] || add_vcs_package myparcel-sdk https://github.com/myparcelnl/sdk myparcelnl/sdk "$(sdk_constraint "$sdk_required")"
  [ -z "$PLUGIN_PATH" ] || add_path_package myparcel-magento PLUGIN_PATH "$PLUGIN_PATH"
  [ -z "$SDK_PATH" ] || add_path_package myparcel-sdk SDK_PATH "$SDK_PATH" "$sdk_required"
  [ -z "$HYVA_MODULE_PATH" ] || add_path_package hyva-checkout-myparcelnl HYVA_MODULE_PATH "$HYVA_MODULE_PATH"

  log "> composer require ${COMPOSER_PACKAGES[*]}"
  as_www composer require --no-progress --update-with-dependencies "${COMPOSER_PACKAGES[@]}" \
    || fail "Composer could not install ${COMPOSER_PACKAGES[*]}$hint"

  remove_compiled_files
  rm -rf var/cache var/page_cache var/view_preprocessed
  printf '%s\n' "$wanted" > "$PLUGIN_MODES_MARKER"
  PLUGIN_MODES_CHANGED=1
}

# setup:di:compile loads every PHP file in a module folder, also the checkout's own vendor/ (from composer install for PhpStorm).
check_checkout_vendors() {
  local path

  [ "$MAGENTO_MODE" = production ] && [ ! -e generated/metadata/global.php ] || return 0
  for path in "$PLUGIN_PATH" "$HYVA_MODULE_PATH"; do
    if [ -n "$path" ] && [ -n "$(ls -A "$path/vendor" 2>/dev/null)" ]; then
      fail "$path/vendor is not empty, and setup:di:compile loads it. Mount an empty folder over it in the php container (compose: tmpfs: [$path/vendor])"
    fi
  done
}

apply_hyva_hook() {
  [ "$WITH_HYVA" = 1 ] || return 0
  log "WITH_HYVA=1: the Hyvä add-on is not available yet. Magento starts without Hyvä."
}
