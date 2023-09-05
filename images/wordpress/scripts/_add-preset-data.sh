add-preset-data() {
  if [ -f preset-data.lock ]; then
    h2 "Preset data is already imported"
    return
  fi

  h1 "Importing preset data"

  touch preset-data.lock

  if [ -d /tmp/sql ]; then
    h2 "Importing sql dump(s)"

    for file in /tmp/sql/*.sql; do
      sed "s/__db_prefix__/$DB_PREFIX/g" "$file" | mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME
    done
  fi

  if [ -d /tmp/plugins/woocommerce/sample-data ]; then
    h2 "Importing WooCommerce sample data"

    wp-activate plugin wordpress-importer

    for file in /tmp/plugins/woocommerce/sample-data/*.xml; do
      sudo -s -u www-data -s wp import "$file" --authors=skip
    done
  fi
}
