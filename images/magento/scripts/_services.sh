# Waits for MariaDB and OpenSearch, and syncs the Magento code from the image into the web-data volume.

WAIT_TIMEOUT=180
CODE_SYNCED=0

wait_for_mariadb() {
  local start=$SECONDS error

  log "Waiting for MariaDB at $DB_HOST:$DB_PORT"
  until error="$(db_query 'SELECT 1' 2>&1 >/dev/null)"; do
    if [ $((SECONDS - start)) -ge "$WAIT_TIMEOUT" ]; then
      fail "MariaDB at $DB_HOST:$DB_PORT did not respond within $WAIT_TIMEOUT s. Last error: $error"
    fi
    sleep 2
  done
}

wait_for_opensearch() {
  local start=$SECONDS url="$OPENSEARCH_SCHEME://$OPENSEARCH_HOST:$OPENSEARCH_PORT" auth=""

  # Through curl's config on stdin, so the password is not in the process list
  if [ -n "$OPENSEARCH_USER" ]; then
    auth="user = \"$(sed 's/[\\"]/\\&/g' <<<"$OPENSEARCH_USER:$OPENSEARCH_PASSWORD")\""
  fi

  log "Waiting for OpenSearch at $url"
  until printf '%s\n' "$auth" | curl -fsS -o /dev/null --max-time 10 -K - \
    "$url/_cluster/health?wait_for_status=yellow&timeout=5s" 2>/dev/null; do
    if [ $((SECONDS - start)) -ge "$WAIT_TIMEOUT" ]; then
      fail "OpenSearch did not start at $url within $WAIT_TIMEOUT s. Check the host name, and give OpenSearch enough memory (Docker memory limit, OPENSEARCH_JAVA_OPTS)."
    fi
    sleep 2
  done
}

# Copies /opt/magento into the volume when the image ID differs. Keeps env.php, pub/media, var/ and plugins/.
# plugins/ holds the bind-mounted checkouts: without the exclude, --delete removes the developer's files.
sync_code() {
  local src=/opt/magento dst=/var/www/html

  cmp -s "$src/.image-id" "$dst/.image-id" && return 0

  log "Syncing the code of image $(cat "$src/.image-id") into $dst"
  rsync -a --delete \
    --exclude=/.image-id \
    --exclude=/.plugin-modes-applied \
    --exclude=/app/etc/env.php \
    --exclude=/pub/media/ \
    --exclude=/var/ \
    --exclude=/plugins/ \
    "$src/" "$dst/"
  rsync -a --ignore-existing "$src/pub/media/" "$dst/pub/media/"
  install -d -o www-data -g www-data "$dst/var"
  rm -f "$dst/.plugin-modes-applied"
  # Last, so that an interrupted sync runs again on the next start
  cp -p "$src/.image-id" "$dst/.image-id"
  CODE_SYNCED=1
}
