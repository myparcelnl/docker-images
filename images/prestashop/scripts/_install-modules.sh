#!/usr/bin/env bash

install-and-enable() {
  module="$1"

  h2 "[module:$module] Installing..."
  sudo -u www-data -s php "$ROOT_DIR/bin/console" prestashop:module install "$module"

  if [[ $? -ne 0 ]]; then
    h2 "[module:$module] Installation failed."
    return
  fi

  h2 "[module:$module] Enabling..."
  sudo -u www-data -s php "$ROOT_DIR/bin/console" prestashop:module enable "$module"

  if [[ $? -ne 0 ]]; then
    h2 "➕ [$module] Enabling failed."
  fi
}

install-modules() {
  h1 "Installing and activating modules"

  link-paths "$TMP_MODULES_DIR" "$PS_MODULES_DIR"

  for path in "$TMP_MODULES_DIR"/*/; do
    module=$(basename "$path")

    if [[ "${INSTALL_MODULES}" == "1" ]]; then
      install-and-enable "$module"
    else
      h2 "[module:$module] Skipped installation"
    fi
  done
}
