install-wordpress() {
  if [ -f install.lock ]; then
    h2 "Installation is already in progress"
    exit 1
  fi

  h1 "Starting WordPress installation"
  touch install.lock

  envsubst < /tmp/wordpress/wp-cli.template.yml > ./wp-cli.yml

  h2 "Waiting for database..."
  wait-for-it -q "$DB_HOST:$DB_PORT" -t 30
  h2 "Database is ready"

  sudo -u www-data -s wp core download 2>/dev/null

  sudo -u www-data -s wp config create --force

  if sudo -u www-data -s wp core is-installed; then
    h2 "WordPress is already installed"
    rm install.lock
    return
  fi

  sudo -u www-data -s wp core install

  sudo -u www-data -s wp rewrite structure '/%postname%/'

  sudo -u www-data -s wp user create "$WP_CUSTOMER_USER" "$WP_CUSTOMER_EMAIL" \
    --user_pass="$WP_CUSTOMER_PASSWORD" \
    --first_name="Customer" \
    --last_name="User"

  rm install.lock
}
