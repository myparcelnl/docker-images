#!/usr/bin/env bash

# Build all assets
build-assets() {
  h2 "Building administration..."
  APP_DEBUG="${VERBOSE_LOGGING}" bin/build-administration.sh

  h2 "Building storefront..."
  APP_DEBUG="${VERBOSE_LOGGING}" bin/build-storefront.sh
}

# With the SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS environment variable, Shopware only builds assets related to plugins.
build-plugin-assets() {
  if [[ "$FORCE_BUILD_PLUGIN_ASSETS" != "1" && -f "build-plugin-assets.lock" ]]; then
    h2 "Plugin assets already built. Set FORCE_BUILD_PLUGIN_ASSETS=1 to force build."
    return
  fi

  SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1 build-assets

  touch "build-plugin-assets.lock"
  touch "clear-cache.lock"
}
