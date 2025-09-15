tail-logs() {
  h2 "Tailing logs..."

    exec tail -F -q -n+2 /tmp/wp-debug.log | perl -p \
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

  exec tail -F -q -n+2 ./wp-content/**/*.log | perl -p \
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
