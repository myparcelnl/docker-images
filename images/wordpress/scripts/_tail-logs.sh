tail-logs() {
  h2 "Tailing logs..."

  # WordPress core/PHP errors go to /tmp/wp-debug.log; the PDK/WooCommerce
  # logger writes hash-named daily files under wp-content/uploads/wc-logs. The
  # wc-logs filename changes on day rollover, so re-glob periodically and
  # restart tail when the set of files changes - this picks up new files
  # without needing a container restart.
  shopt -s nullglob

  {
    first=1
    while true; do
      files=(/tmp/wp-debug.log ./wp-content/uploads/wc-logs/*.log)

      # Dump existing content on first run (as before); only follow new
      # content on subsequent restarts to avoid re-printing the whole file.
      if [ "$first" -eq 1 ]; then
        start='-n+2'
        first=0
      else
        start='-n0'
      fi

      tail -F -q "$start" "${files[@]}" 2>/dev/null &
      tpid=$!

      snapshot="${files[*]}"
      while sleep 5; do
        current=(/tmp/wp-debug.log ./wp-content/uploads/wc-logs/*.log)
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
