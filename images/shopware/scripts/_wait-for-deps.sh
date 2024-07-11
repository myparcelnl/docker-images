#!/usr/bin/env bash

wait-for-deps() {
  if ! wait-for-it -q -t 0 "$DB_HOST:$DB_PORT"; then
    h2 "Waiting for database..."
    wait-for-it -q -t 30 "$DB_HOST:$DB_PORT"
    h2 "Database is ready."
  fi

  if [[ "$SHOPWARE_ES_ENABLED" == "1" ]]; then
    h2 "Waiting for ElasticSearch..."
    curl -s -XGET "http://$ES_HOST:$ES_PORT/_cluster/health?wait_for_status=yellow&timeout=30s" > /dev/null
    h2 "ElasticSearch is ready."
  fi
}
