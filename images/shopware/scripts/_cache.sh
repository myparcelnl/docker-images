#!/usr/bin/env bash

clear-cache() {
  h2 "Clearing cache..."
  bin/console "$verbosity" cache:clear
}

warmup-cache() {
  h2 "Warming up cache..."
  bin/console "$verbosity" cache:warmup
}
