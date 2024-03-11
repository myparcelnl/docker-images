#!/usr/bin/env bash

install-plugins() {
  h1 "Installing and activating plugins"
  link-paths "$TMP_PLUGINS_DIR" "$SW_PLUGINS_DIR"

  h2 "Refreshing plugins"
  bin/console "$verbosity" plugin:refresh

  for path in "$TMP_PLUGINS_DIR"/*/; do
    plugin=$(basename "$path")

    if [ bin/console plugin:info "$plugin" ]; then
      h2 "[plugin:$plugin] Plugin already installed, skipping..."
      continue
    fi

    if [[ -f "$path/composer.json" ]]; then
      install-dependencies-composer "$path"
    fi

    h2 "[plugin:$plugin] Installing and activating..."
    bin/console plugin:install "$verbosity" --activate "$plugin"
  done

  build-plugin-assets
}
