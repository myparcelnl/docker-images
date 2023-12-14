#!/usr/bin/env bash

export TMP_PLUGINS_DIR="/tmp/plugins"
export SW_PLUGINS_DIR="$PROJECT_ROOT/custom/plugins"

if [[ "$VERBOSE_LOGGING" == "1" ]]; then
  export verbosity=-vvv
else
  export verbosity=-v
fi

for script in /tmp/scripts/_*; do source "$script"; done

# Start php fpm in the background in advance.
start-php-fpm

install-shopware
install-plugins

if [[ "$FORCE_CLEAR_CACHE" == "1" || -f "clear-cache.lock" ]]; then
  clear-cache
  warmup-cache
fi

reset-permissions

h1 "🔵 Shopware is ready at ${FULL_URL}/admin ✨"
tail -f var/log/*.log & wait
