#!/usr/bin/env bash

install-shopware() {
  install-dependencies-node
  wait-for-deps

  h1 "Starting Shopware installation"

  if [ -f install.lock ]; then
    h2 "Shopware is already installed."
    return
  fi

  if [[ ! -f .psh.yaml.override ]]; then
    h2 "Creating psh.yaml.override..."
    envsubst < /tmp/.psh.yaml.override.template > .psh.yaml.override
  fi

  h2 "Running installation..."
  php bin/console "$verbosity" system:install --basic-setup --create-database --force

  # if command failed
  if [ $? -ne 0 ]; then
    h2 "Shopware installation failed."
    exit 1
  fi

  h2 "Shopware installation succeeded."
  touch install.lock
  touch "clear-cache.lock"

  add-preset-data
}
