#!/bin/bash

####### Update all packages in default Ubuntu and install docker and docker-compose #######
export DEBIAN_FRONTEND=noninteractive
apt-get update 
apt-get upgrade -y
apt-get install docker-compose docker.io unzip -y

export $(cat .env | xargs)
docker-compose up -d
cd php
docker build -f Dockerfile74 .
docker build -f Dockerfile80 .
docker build -f Dockerfile81 .
docker build -f Dockerfile82 .
docker pull mariadb:10.4
