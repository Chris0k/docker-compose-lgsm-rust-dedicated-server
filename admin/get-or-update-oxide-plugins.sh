#!/bin/bash

service=$1

docker compose exec -Tu linuxgsm "$service" /utils/get-or-update-plugins.sh "$service"
