#!/bin/bash

export TMP_MODULES_DIR="/tmp/modules"
export PS_MODULES_DIR="$ROOT_DIR/modules"

for script in /tmp/scripts/_*; do source $script; done

# Start php fpm in the background in advance.
start-php-fpm

install-prestashop
install-modules

add-preset-data

clear-cache
warmup-cache

reset-permissions

tail-logs

h1 "🐧 PrestaShop is ready at ${FULL_URL} ✨"
sleep infinity
