#!/bin/bash

# Docker Compose project name
COMPOSE_PROJECT_NAME="posnetwork"
PARENT_DIR="$(pwd)/.."

# Function to get p2p address from a Prysm beacon container
get_p2p_address() {
    local container_name=$1
    local host_port=$2

    # Use curl to get the node identity from Prysm's HTTP API
    local response=$(curl -s http://localhost:$host_port/eth/v1/node/identity)

    # Extract the last p2p address from the response
    local p2p_address=$(echo "$response" | jq -r '.data.p2p_addresses[-1]')

    echo "$p2p_address"
}

# Function to get ENR from a Prysm beacon container
get_enr() {
    local container_name=$1
    local host_port=$2

    # Use curl to get the node identity from Prysm's HTTP API
    local response=$(curl -s http://localhost:$host_port/eth/v1/node/identity)

    # Extract the ENR from the response
    local enr=$(echo "$response" | jq -r '.data.enr')

    echo "$enr"
}

echo "Gathering P2P addresses from beacon nodes"
# Get p2p addresses
P2P1=$(get_p2p_address "${COMPOSE_PROJECT_NAME}-beacon1-1" "3500")
echo "P2P address for beacon1: $P2P1"
P2P2=$(get_p2p_address "${COMPOSE_PROJECT_NAME}-beacon2-1" "3501")
echo "P2P address for beacon2: $P2P2"
P2P3=$(get_p2p_address "${COMPOSE_PROJECT_NAME}-beacon3-1" "3502")
echo "P2P address for beacon3: $P2P3"

if [ -z "$P2P1" ] || [ -z "$P2P2" ] || [ -z "$P2P3" ]; then
    echo "Failed to retrieve P2P address for one or more beacon nodes."
    exit 1
fi

echo "Gathering ENRs from beacon nodes"
# Get ENRs
ENR1=$(get_enr "${COMPOSE_PROJECT_NAME}-beacon1-1" "3500")
echo "ENR for beacon1: $ENR1"
ENR2=$(get_enr "${COMPOSE_PROJECT_NAME}-beacon2-1" "3501")
echo "ENR for beacon2: $ENR2"
ENR3=$(get_enr "${COMPOSE_PROJECT_NAME}-beacon3-1" "3502")
echo "ENR for beacon3: $ENR3"

if [ -z "$ENR1" ] || [ -z "$ENR2" ] || [ -z "$ENR3" ]; then
    echo "Failed to retrieve ENR for one or more beacon nodes."
    exit 1
fi

# Function to update Docker Compose file
run_sed() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

update_docker_compose() {
    local p2p_data=$1
    local p2p_data2=$2
    local enr_data=$3
    local enr_data2=$4
    local peer_replace_token=$5

    if [ ! -f ../docker-compose.yml.bak ]; then
        cp ../docker-compose.yml ../docker-compose.yml.bak
    fi

    if [ -z "$enr_data" ] || [ -z "$enr_data2" ]; then
        echo "Failed to supply enr_data or enr_data2."
        exit 1
    fi

    # Construct the replacement content
    # local replacement="      - --bootstrap-node=$enr_data,$enr_data2\n      - --peer=$p2p_data\n      - --peer=$p2p_data2"
    local replacement="      - --bootstrap-node=$enr_data\n      - --bootstrap-node=$enr_data2"

    # Update the Docker Compose file
    awk -v start="${peer_replace_token}Start" -v end="${peer_replace_token}End" -v repl="$replacement" '
    $0 ~ start {print; print repl; f=1; next}
    $0 ~ end {f=0; print; next}
    !f
    ' ../docker-compose.yml > ../docker-compose.tmp && mv ../docker-compose.tmp ../docker-compose.yml
}


# Update Docker Compose file for each beacon node
# echo "Updating Docker Compose file for beacon1..."
update_docker_compose "$P2P2" "$P2P3" "$ENR2" "$ENR3" "#beacon1ScriptClusterToken"

echo "Updating Docker Compose file for beacon2..."
update_docker_compose "$P2P1" "$P2P3" "$ENR1" "$ENR3" "#beacon2ScriptClusterToken"

echo "Updating Docker Compose file for beacon3..."
update_docker_compose "$P2P1" "$P2P2" "$ENR1" "$ENR2" "#beacon3ScriptClusterToken"

echo "Docker Compose file updated."

# Restart beacon nodes
echo "Restarting beacon nodes..."
docker compose up -d --no-deps beacon1 beacon2 beacon3

echo "All beacon nodes updated and restarted."

# Optional: Check peer count after restart
check_peer_count() {
    local container_name=$1
    local host_port=$2
    echo "Checking peer count for $container_name:"
    curl -s http://localhost:$host_port/eth/v1/node/peer_count | jq
}

# Wait for a moment to allow connections to establish
echo "wait 30 secs for restart to check beacon peers"
sleep 30

check_peer_count "${COMPOSE_PROJECT_NAME}-beacon1-1" "3500"
check_peer_count "${COMPOSE_PROJECT_NAME}-beacon2-1" "3501"
check_peer_count "${COMPOSE_PROJECT_NAME}-beacon3-1" "3502"

echo "Peer check completed."