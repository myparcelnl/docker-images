#!/usr/bin/env bash

add-preset-data() {
  h1 "Adding preset data..."
  php /cli/app database:setup $([[ $FORCE_DATABASE_UPDATE == "1" ]] && echo "--force")
}
