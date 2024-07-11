#!/usr/bin/env bash

start-nginx() {
  h1 "Starting nginx..."

  if pidof -s nginx > /dev/null; then
    h2 "nginx is already running"
    return
  fi

  chmod +w /etc/nginx/conf.d
  auto_envsubst # from _envsubst-on-templates.sh

  nginx -D

  if [ "$?" -eq 0 ]; then
    h2 "Started nginx."
  else
    h2 "Failed to start nginx."
    exit 1
  fi
}