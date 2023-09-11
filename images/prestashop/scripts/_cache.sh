#!/usr/bin/env bash

clear-cache() {
  h2 "Clearing cache..."
  sudo -u www-data -s php bin/console cache:clear
}

warmup-cache() {
  h2 "Warming up cache..."
  sudo -u www-data -s php bin/console cache:warmup
}
