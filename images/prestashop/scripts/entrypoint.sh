#!/bin/bash

for script in /tmp/scripts/_*; do source $script; done

# Start php fpm in the background in advance.
start-php-fpm

install-cli
install-prestashop
install-modules

add-preset-data

reset-permissions

clear-cache
warmup-cache

reset-permissions

if [ "${WITH_NGINX}" -eq 1 ]; then
  start-nginx
fi

h1 "🐧 PrestaShop is ready at ${FULL_URL} ✨"

tail-logs
