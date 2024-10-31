#!/bin/bash

NETWORK="dockernet"
CONFIG_DIR="../config"
KEYSTORE_DIR="$(pwd)/$CONFIG_DIR"
NUM_VALIDATORS=3
SEED="dockernet_seed"  # Change this seed to generate different sets of keys

mkdir -p "$KEYSTORE_DIR"

for i in $(seq 1 $NUM_VALIDATORS); do
    echo "Generating keystore for validator $i"
    mkdir -p "$KEYSTORE_DIR/validator_$i/execution"

    echo "Generating password.txt for validator $i"
    # Generate deterministic password
    echo -n "${SEED}_password_$i" | openssl dgst -sha256 -binary | xxd -p -c 32 > "$KEYSTORE_DIR/validator_$i/execution/password.txt"

    # Generate deterministic private key
    PRIVATE_KEY=$(echo -n "${SEED}_privatekey_$i" | openssl dgst -sha256 -binary | xxd -p -c 32)

    echo "Creating account using the generated private key"
    echo "Private key: $PRIVATE_KEY"
    echo "$KEYSTORE_DIR/validator_$i"
    # Create account using the generated private key
    echo "$PRIVATE_KEY" > "$KEYSTORE_DIR/validator_$i/temp_private_key"
    docker run --user $(id -u):$(id -g) --rm -v "$KEYSTORE_DIR/validator_$i:/data" ethereum/client-go:latest \
        account import --datadir /data --password /data/execution/password.txt /data/temp_private_key
    rm "$KEYSTORE_DIR/validator_$i/temp_private_key"

    echo "Generating JWT token for validator $i"
    # Generate deterministic JWT token
    echo -n "${SEED}_jwt_$i" | openssl dgst -sha256 -binary | xxd -p -c 32 > "$KEYSTORE_DIR/validator_$i/jwt.hex"

    # Set permissions
    chmod 600 "$KEYSTORE_DIR/validator_$i/jwt.hex" "$KEYSTORE_DIR/validator_$i/execution/password.txt"

    # Change ownership of the keystore directory
    chown -R $(id -u):$(id -g) "$KEYSTORE_DIR/validator_$i"

    # Move the keystore files
    mv "$KEYSTORE_DIR/validator_$i/keystore" "$KEYSTORE_DIR/validator_$i/execution/"
    rmdir "$KEYSTORE_DIR/validator_$i/keystore"
done

# Generate deterministic private keys for beacon nodes
for i in $(seq 1 $NUM_VALIDATORS); do
    BEACON_KEY_DIR="$KEYSTORE_DIR/validator_$i"
    BEACON_KEY_FILE="$BEACON_KEY_DIR/beacon_node_key"

    # Generate a deterministic private key using the seed
    echo -n "${SEED}_beacon_$i" | openssl dgst -sha256 -binary | xxd -p -c 32 > "$BEACON_KEY_FILE"

    chmod 600 "$BEACON_KEY_FILE"
    echo "Beacon key generated for validator $i: $(cat $BEACON_KEY_FILE)"
done