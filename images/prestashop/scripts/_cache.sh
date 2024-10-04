#!/usr/bin/env bash

clear-cache() {
  h2 "Clearing cache..."
  sudo -u www-data -s php bin/console cache:clear --no-warmup
}

warmup-cache() {
  h2 "Warming up cache..."
  sudo -u www-data -s php bin/console cache:warmup --no-optional-warmers
}
