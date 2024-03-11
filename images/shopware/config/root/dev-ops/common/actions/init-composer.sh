#!/usr/bin/env bash

# Copy of the original file, but except removing all vendor directories. This slows down a restart for no reason.
# Source: https://github.com/shopware/development/blob/v6.4.17.2/dev-ops/common/actions/init-composer.sh

composer update --no-interaction --optimize-autoloader --no-scripts
composer install --no-interaction --optimize-autoloader --working-dir=dev-ops/analyze
if [ -e platform/src/Recovery ]; then composer install --no-interaction --optimize-autoloader --working-dir=platform/src/Recovery; fi

if grep -q static-analyze platform/composer.json; then composer update --working-dir=platform; fi
