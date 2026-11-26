# Shared functions for the start scripts. Sourced by entrypoint.sh, which runs as root in /var/www/html.

log() {
  printf '[entrypoint] %s\n' "$*"
}

fail() {
  printf '[entrypoint] ERROR: %s\n' "$*" >&2
  exit 1
}

as_www() {
  runuser -u www-data -- "$@"
}

# Logs only the command name: the arguments can hold passwords.
magento() {
  log "> bin/magento $1"
  as_www php bin/magento "$@"
}

# The password goes in an option file: with MYSQL_PWD the client warns about a passwordless login.
db_query() {
  mariadb --defaults-extra-file=<(printf '[client]\npassword="%s"\n' "$(sed 's/[\\"]/\\&/g' <<<"$DB_PASSWORD")") \
    --connect-timeout=5 -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -N -B "$DB_NAME" -e "$1"
}

sql_quote() {
  printf "'%s'" "${1//\'/\'\'}"
}

CONFIG_CHANGED=0

# Sets a config value on default scope. Sets CONFIG_CHANGED=1 when the value changed.
set_config() {
  local path value current
  path="$(sql_quote "$1")"
  value="$(sql_quote "$2")"
  current="$(db_query "SELECT value FROM core_config_data WHERE scope = 'default' AND scope_id = 0 AND path = $path")"

  if [ "$current" != "$2" ]; then
    db_query "INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('default', 0, $path, $value)
      ON DUPLICATE KEY UPDATE value = VALUES(value)"
    CONFIG_CHANGED=1
  fi
}
