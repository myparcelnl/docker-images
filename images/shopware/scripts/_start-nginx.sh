#!/usr/bin/env bash

start-nginx() {
  h1 "Starting nginx..."

  if pidof -s nginx > /dev/null; then
    h2 "nginx is already running"
    return
  fi

  nginx;

  if [ "$?" -eq 0 ]; then
    h2 "Started nginx."
  else
    h2 "Failed to start nginx."
    exit 1
  fi
}