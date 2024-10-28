#!/usr/bin/env bash

start-nginx() {
  h1 "Starting nginx..."

  if pidof -s nginx > /dev/null; then
    h2 "nginx is already running"
    return
  fi

  # replace docker php fpm location with local one in nginx default config
  sed -i -e 's|php:9000;|localhost:9000;|g' /etc/nginx/http.d/default.conf

  # start nginx
  nginx;

  if [ "$?" -eq 0 ]; then
    h2 "Started nginx."
  else
    h2 "Failed to start nginx."
    exit 1
  fi
}