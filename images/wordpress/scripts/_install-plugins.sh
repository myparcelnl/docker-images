install-plugins() {
  h1 "Linking, installing and activating plugins..."

  PLUGINS_FOUND=$(find "$TMP_PLUGINS_DIR" -type d -mindepth 1 -maxdepth 1)

  link-paths "$TMP_PLUGINS_DIR" "$WP_PLUGINS_DIR"

  if [ -n "$WP_SKIP_PLUGINS" ]; then
    h2 "Skipping plugin installation because WP_SKIP_PLUGINS is set."
    return
  fi

  if [ -z "$PLUGINS_FOUND" ]; then
    h2 "No local plugins to install."
  else
    h2 "Installing local plugins..."
    for path in $PLUGINS_FOUND; do
      plugin=$(basename "$path")

      wp-activate plugin "$plugin"
    done
  fi

  PLUGINS_LIST=$(echo "$WP_PLUGINS" | tr ',' '\n')

  if [ -z "$PLUGINS_LIST" ]; then
    h2 "No remote plugins to install."
  else
    h2 "Downloading and installing remote plugins..."

    for plugin in $PLUGINS_LIST; do
      wp-activate plugin "$plugin"
    done
  fi

  h2 "Finished installing and activating plugins."
}
