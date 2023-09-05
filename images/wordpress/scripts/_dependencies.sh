install-dependencies-composer() {
  composer install \
    --no-interaction \
    --no-suggest \
    "$@"
}

install-dependencies-node() {
  yarn install "$@"
}
