#!/bin/bash

set -e

backup_source_file=$1
service=$2

if [ ! -d .git -a ! -d admin ]; then
  echo 'ERROR: must run this command from the root of the git repository.' >&2
  exit 1
fi

if [ "$#" -ne 2 ]; then
  echo 'ERROR: insufficient arguments given.  For example,' >&2
  echo '    ./admin/backup/restore-backup.sh backups/file.tgz lgsm' >&2
  exit 1
fi

ls "$backup_source_file" > /dev/null

#if [ ! "$(tar -tzf "$backup_source_file" | head -n1)" = "$service" ]; then
#  echo "File: $backup_source_file"
#  echo 'ERROR: File exists but not a valid backup.' >&2
#  exit 1
#fi

cat <<EOF
WARNING: This is a permanent action.

All maps, config, plugin config, and lgsm config  will be destroyed including
save backups in order to restore your backup:

    $backup_source_file

EOF
read -erp 'Do you wish to delete the current map? (y/N) ' response

if [ ! "$response" = y -a ! "$response" = Y ]; then
  echo 'Operation aborted.  Respond "y" next time if you want to proceed.'
  exit
fi

server_container_id="$(docker compose ps -q $service)"

if [ -z "${server_container_id}" ]; then
  echo 'ERROR: Rust server not running... did you "docker compose up -d"?'
  exit 1
fi

backup_file="${1##*/}"

echo "Restoring $backup_file"

# copy backup file to server
backup_file="${1##*/}"
docker cp "$backup_source_file" "${server_container_id}:/home/linuxgsm/${backup_file}"
docker compose exec -T "$service" chown linuxgsm: /home/linuxgsm/"${backup_file}"

# restore backup and reboot the server
docker compose exec -Tu linuxgsm "$service" bash -ex <<EOF
# kill the uptime monitor before restoring
if pgrep -f monitor-rust-server.sh &> /dev/null; then
  echo 'Stopping uptime monitor.'
  kill "\$(pgrep -f monitor-rust-server.sh)"
fi
./rustserver stop || true

REMOVE_DIRS=(
  lgsm
  serverfiles/server
)
if [ -d serverfiles/oxide ]; then
  REMOVE_DIRS+=( serverfiles/oxide )
fi

find "\${REMOVE_DIRS[@]}" \\( ! -type d \\) -exec rm -f {} +
tar -xzvf '${backup_file}'

rm -f '${backup_file}'

cat <<'EOT'
Rebooting the server in 3 seconds...
Watch restart logs with the following command.

    docker compose logs -f

EOT
echo ''
sleep 3
pgrep tail | xargs kill
EOF
