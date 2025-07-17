#!/bin/bash

docker stop api-relay

docker rm api-relay

docker stop aiportal

docker rm aiportal

docker stop keycloak

docker rm keycloak

docker stop ffm-hub-db

docker rm ffm-hub-db

docker volume rm deploy_keycloak_db

docker stop ffm-hub-prometheus

docker rm ffm-hub-prometheus

docker stop ffm-hub-grafana

docker rm ffm-hub-grafana

