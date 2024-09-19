#!/bin/bash

declare -i term_width=70

for script in /tmp/scripts/_*; do source $script; done

# Start php fpm in the background in advance.
start-php-fpm

install-wordpress
install-theme
install-plugins

add-preset-data

reset-permissions

if [ "${WITH_NGINX}" -eq 1 ]; then
  start-nginx
fi

h1 "📝 WordPress is ready at ${FULL_URL} ✨"

tail-logs
