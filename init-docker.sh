#!/bin/bash

docker stop api-relay

docker rm api-relay

docker stop aiportal

docker rm aiportal

docker stop keycloak

docker rm keycloak
