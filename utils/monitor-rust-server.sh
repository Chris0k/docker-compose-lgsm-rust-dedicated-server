#!/bin/bash

env_file=$1

LOGFILE=/home/linuxgsm/log/autoheal.log
[ ! -r "/$env_file" ] || source "/$env_file"

function wait-for-rust() {
  until pgrep "$@"; do
    sleep 1
  done
}
function graceful-kill() {
  echo "$(date) - auto-heal graceful kill" >> "$LOGFILE"
  pgrep tail | xargs -- kill
}

function hard-kill() {
  echo "$(date) - auto-heal HARD kill" >> "$LOGFILE"
  pgrep tail | xargs -- kill -9
}

function kill-container-on-absence-of() {
  local retry=0
  while true; do
    sleep 10
    if pgrep "$@"; then
      retry=0
    else
      (( retry=retry+1 ))
    fi
    if [ "$retry" -ge 6 ]; then
      hard-kill
    elif [ "$retry" -ge 3 ]; then
      graceful-kill
    fi
  done
}

if [ ! "${uptime_monitoring:-}" = true ]; then
  echo 'RustDedicated will not be monitored.'
  echo 'Set uptime_monitoring=true in $env_file to enable autoheal.'
  exit
else
  echo 'Monitoring RustDedicated for automatic restart.'
fi
# discard further output
echo "$(date) - auto-heal wait-for" >> "$LOGFILE"
exec &> /dev/null
wait-for RustDedicated
kill-container-on-absence-of RustDedicated
