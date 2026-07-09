tail-logs() {
  h2 "Tailing logs..."

  # WordPress core/PHP errors go to /tmp/wp-debug.log; the PDK/WooCommerce logger
  # writes hash-named daily files under wp-content/uploads/wc-logs. The wc-logs
  # filename changes on day rollover, so re-glob periodically and restart tail
  # when the set of files changes - picks up new files without a restart.
  _log_files() {
    printf '%s\n' /tmp/wp-debug.log
    local f
    for f in "${ROOT_DIR:-/var/www/html}"/wp-content/uploads/wc-logs/*.log; do
      [ -e "$f" ] && printf '%s\n' "$f"
    done
  }

  {
    first=1
    while true; do
      mapfile -t files < <(_log_files)

      # First run: show the tail of existing files for context; on restart only
      # follow new content to avoid re-dumping whole (persisted) files.
      if [ "$first" -eq 1 ]; then
        start='-n200'
        first=0
      else
        start='-n0'
      fi

      tail -F -q "$start" "${files[@]}" 2>/dev/null &
      tpid=$!

      snapshot="${files[*]}"
      while sleep 5; do
        mapfile -t current < <(_log_files)
        if [ "${current[*]}" != "$snapshot" ]; then
          break
        fi
      done

      kill "$tpid" 2>/dev/null
      wait "$tpid" 2>/dev/null
    done
  } | perl -p \
    -e 'BEGIN { $| = 1 }' \
    -e 's/(^.+\[PDK\])/\e[1;32m$1\e[0m/g;' \
    -e 's/(\[PDK\])/\e[36m$&\e[0m/g;' \
    -e 's/(ERROR|CRITICAL|FATAL|EMERGENCY)/\e[31m$&\e[0m/g;' \
    -e 's/(WARNING)/\e[33m$&\e[0m/g;' \
    -e 's/(NOTICE)/\e[35m$&\e[0m/g;' \
    -e 's/(INFO)/\e[34m$&\e[0m/g;' \
    -e 's/(DEBUG)/\e[30m$&\e[0m/g;' \
    -e 's/(".*?":)/\e[1;34m$1\e[0m/g;' \
    -e 's/({|}|,)/\e[1;34m$&\e[0m/g;' \
    >> /proc/1/fd/1
}
