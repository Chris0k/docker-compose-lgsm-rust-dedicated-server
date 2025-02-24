#!/bin/bash

service=$1
user=$2

docker exec -itu "${user:-linuxgsm}" $(docker compose ps -q "$service") /bin/bash
