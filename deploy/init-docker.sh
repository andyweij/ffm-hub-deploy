#!/bin/bash

docker stop api-relay

docker rm api-relay

docker stop aiportal

docker rm aiportal

docker stop keycloak

docker rm keycloak

docker stop afs-hub-db

docker rm afs-hub-db

docker volume rm deploy_keycloak_db

docker stop afs-hub-prometheus

docker rm afs-hub-prometheus

docker stop afs-hub-grafana

docker rm afs-hub-grafana

