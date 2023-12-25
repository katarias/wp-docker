#!/bin/bash

####### Update all packages in default Ubuntu and install docker and docker-compose #######
apt-get update 
apt-get upgrade -y
apt-get install docker-compose docker.io unzip -y

export $(cat .env | xargs)
#echo $dockerpass |docker login -u prabinjha --password-stdin
docker-compose up -d
