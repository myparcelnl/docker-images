#!/bin/bash

for script in /tmp/scripts/_*; do source $script; done

# Start php fpm in the background in advance.
start-php-fpm

install-prestashop
install-modules

add-preset-data

reset-permissions

clear-cache
warmup-cache

reset-permissions

h1 "🐧 PrestaShop is ready at ${FULL_URL} ✨"

tail-logs
