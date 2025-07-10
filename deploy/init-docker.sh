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

docker stop deploy-prometheus-1

docker rm deploy-prometheus-1

docker stop deploy-grafana-1

docker rm deploy-grafana-1

