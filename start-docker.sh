#!/usr/bin/env bash

echo "First time you should run from /script the generate_bootnode.sh"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "Running scripts clean.sh"
cd scripts
./clean.sh


# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
    result=$(sudo ./check_config.sh)
else
    result=$(./check_config.sh)
fi

# Use the output in logic
if [[ "$result" == "true" ]]; then
    echo "All checks passed. Skipping config generation."
else
    echo "Generating config..."
    ./generate_config.sh
fi

echo "Generating genesis file..."
./generate_genesis.sh
cd  ../

echo "starting the bootnode..."
docker compose up -d bootnode

cd scripts
echo "check bootnode enode"
./bootnode_check.sh
cd  ../

echo "starting geth nodes initiation..."
docker compose up -d geth1-init geth2-init  geth3-init

# wait for geth1-1 init to finish
sleep 5

echo "starting Ethereum PoS Nodes..."
# cd ../
docker compose up geth1 geth2 geth3 beacon1 beacon2 beacon3 validator1 validator2 validator3 -d

echo "wait 30 secs for startup"
sleep 30

cd scripts

# Now geth clients connect to the others via bootnode.
# We don't need to manually add peers for each client.
echo "Updating Geth cluster and connecting execution nodes..."

source ./update_geth_cluster.sh

# Check EL peers
check_peers "${COMPOSE_PROJECT_NAME}-geth1-1"
check_peers "${COMPOSE_PROJECT_NAME}-geth2-1"
check_peers "${COMPOSE_PROJECT_NAME}-geth3-1"

echo "Execution Peer check completed."

# echo "wait 30 secs"
# sleep 30

echo "updating Beacon Cluster, connecting consensus nodes..."
./update_beacon_cluster.sh

cd ..

