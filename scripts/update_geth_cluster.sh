#!/bin/bash

# Docker Compose project name
COMPOSE_PROJECT_NAME="dockernet"

# Function to get enode from a Geth container
get_enode() {
    local container_name=$1
    local external_docker=$2

    # Use geth attach to get the enode
    local enode=$(docker exec $container_name geth attach --exec "admin.nodeInfo.enode" | tr -d '"')

    if [ -z "$enode" ]; then
        echo "Failed to retrieve enode from container $container_name" >&2
        return 1
    fi

    # Replace IP and port
    enode=$(echo "$enode" | sed "s/\(@\)127\.0\.0\.1/\1$external_docker/")
    echo "$enode"
}

# Get enodes
ENODE1=$(get_enode "${COMPOSE_PROJECT_NAME}-geth1-1" "geth1")
ENODE2=$(get_enode "${COMPOSE_PROJECT_NAME}-geth2-1" "geth2")
ENODE3=$(get_enode "${COMPOSE_PROJECT_NAME}-geth3-1" "geth3")

if [ -z "$ENODE1" ] || [ -z "$ENODE2" ] || [ -z "$ENODE3" ]; then
    echo "Failed to retrieve enode for one or more Geth nodes."
    exit 1
fi

echo "All Geth nodes successfully loaded"

echo "Enode for geth1: $ENODE1"
echo "Enode for geth2: $ENODE2"
echo "Enode for geth3: $ENODE3"

# Function to add peer
add_peer() {
    local container_name=$1
    local peer_enode=$2

    docker exec $container_name geth attach --exec "admin.addPeer(\"$peer_enode\")" > /dev/null 2>&1
}

# Add peers
echo "Adding peers to geth1"
add_peer "${COMPOSE_PROJECT_NAME}-geth1-1" "$ENODE2"
add_peer "${COMPOSE_PROJECT_NAME}-geth1-1" "$ENODE3"

echo "Adding peers to geth2"
add_peer "${COMPOSE_PROJECT_NAME}-geth2-1" "$ENODE1"
add_peer "${COMPOSE_PROJECT_NAME}-geth2-1" "$ENODE3"

echo "Adding peers to geth3"
add_peer "${COMPOSE_PROJECT_NAME}-geth3-1" "$ENODE1"
add_peer "${COMPOSE_PROJECT_NAME}-geth3-1" "$ENODE2"

echo "Peer addition completed."

# Function to check peers
check_peers() {
    local container_name=$1

    echo "Checking Execution/ geth peers for $container_name:"
    docker exec $container_name geth attach --exec "admin.peers"
}

# Check peers after adding
check_peers "${COMPOSE_PROJECT_NAME}-geth1-1"
check_peers "${COMPOSE_PROJECT_NAME}-geth2-1"
check_peers "${COMPOSE_PROJECT_NAME}-geth3-1"

echo "Execution Peer check completed."