#!/usr/bin/env bash

start-php-fpm() {
  h1 "Starting php-fpm..."

  if pidof -s php-fpm > /dev/null; then
    h2 "php-fpm is already running"
    return
  fi

  php-fpm -D

  if [ "$?" -eq 0 ]; then
    h2 "Started php-fpm."
  else
    h2 "Failed to start php-fpm."
    exit 1
  fi
}
