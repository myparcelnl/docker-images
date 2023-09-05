install-plugins() {
  h1 "Linking, installing and activating plugins..."

  link-paths "$TMP_PLUGINS_DIR" "$WP_PLUGINS_DIR"

  if [ -n "$WP_SKIP_PLUGINS" ]; then
    h2 "Skipping plugin installation because WP_SKIP_PLUGINS is set."
    return
  fi

  for path in "$TMP_PLUGINS_DIR"/*/; do
    plugin=$(basename "$path")

    wp-activate plugin "$plugin"
  done

  h2 "Finished installing and activating plugins."
}
