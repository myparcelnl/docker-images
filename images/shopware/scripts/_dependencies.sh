#!/usr/bin/env bash

install-dependencies-composer() {
  dir=$1

  if [[ "$FORCE_COMPOSER_INSTALL" != "1" && -d "$1/vendor" ]]; then
    h2 "Skipping composer install, because $1/vendor directory already exists. Set FORCE_COMPOSER_INSTALL=1 to force install."
    return
  fi

  h2 "Installing composer dependencies in $dir..."
  # Skip autoloader optimization if already done to speed up the process
  composer install \
    --no-interaction \
    --no-progress \
    --no-scripts \
    $(test "vendor/autoload.php" && echo "--no-autoloader") \
    --working-dir "$dir"
}

install-dependencies-node() {
  if [[ "$FORCE_YARN_INSTALL" != "1" && -d "node_modules" ]]; then
    h2 "Skipping yarn install, because node_modules directory already exists. Set FORCE_YARN_INSTALL=1 to force install."
    return
  fi

  h2 "Installing node dependencies..."
  yarn install "$@"
}
