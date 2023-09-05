#!/bin/bash

declare -i term_width=70

export TMP_PLUGINS_DIR="/tmp/plugins"
export WP_PLUGINS_DIR="$ROOT_DIR/wp-content/plugins"

for script in /tmp/scripts/_*; do source $script; done

# Start php fpm in the background in advance.
start-php-fpm

install-wordpress
install-theme
install-plugins

add-preset-data

reset-permissions

h1 "📝 WordPress is ready at ${FULL_URL} ✨"

tail-logs
