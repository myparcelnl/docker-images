#!/usr/bin/env bash

tail-logs() {
  h2 "Tailing logs..."

  # Prepare log files
  logFiles=()

  for modulePath in myparcelnl myparcelbe;do
    module=$(basename $modulePath)
    mkdir -p "var/logs/$module"

    for level in alert debug info notice warning critical emergency error; do
      logFile="var/logs/$module/$level.log"
      touch "$logFile"
      logFiles+=("$logFile")
    done
  done;

  exec tail -f -q -n+2 ${logFiles[@]} >> /proc/1/fd/1
}
