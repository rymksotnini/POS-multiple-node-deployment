#!/usr/bin/env bash

# Remove all containers
docker rm -f $(docker ps -a -q -f name='^(dockernet-)') 2>/dev/null || true

echo 'Removing validator-specific data... etc'
# Remove validator-specific data
for dir in ../config/validator_*/; do
    echo "Removing data from ${dir}consensus/beacondata... etc"
    rm -Rf "${dir}consensus/beacondata" "${dir}consensus/validatordata" "${dir}execution/geth"
done
if [ -f ../docker-compose.pre-beacon-cluster.yml ]; then
    rm ../docker-compose.pre-beacon-cluster.yml
fi

if [ -f ../docker-compose.yml.bak ]; then
    rm ../docker-compose.yml.bak
fi

