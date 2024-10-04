#!/usr/bin/env bash

install-cli() {
  h1 "Installing CLI dependencies"

  composer install --no-plugins --no-interaction --working-dir="/cli"
}
