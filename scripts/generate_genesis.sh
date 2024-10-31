#!/bin/bash


CONFIG_DIR="$(pwd)/../config/"
VALIDATORS_BASE_DIR="$CONFIG_DIR"
GENESIS_TEMPLATE="$(pwd)/../templates/execution_template/genesis_template.json"
GENESIS_OUTPUT="$(pwd)/../templates/execution_template/tmp-genesis.json"
GENESIS_SZZ_OUTPUT="$(pwd)/../templates/consensus_template/tmp-genesis.ssz"
CONSENSUS_TEMPLATE_CONFIG="$(pwd)/../templates/consensus_template/config.yml"
NUM_VALIDATORS=3  # Change this to the number of validators you need

CHAIN_ID=14800
VALIDATOR_BALANCE="0x43c33c193756480000000"
ADDRESSES=()
ADDRESSES_JSON=()

for i in $(seq 1 $NUM_VALIDATORS); do

    # Define the keystore path
    KEYSTORE_DIR="$VALIDATORS_BASE_DIR/validator_$i/execution/keystore"
    # Find the UTC file and extract the address
    ADDRESS=$(awk -F'"' '/"address"/ {print $4}' "$KEYSTORE_DIR"/UTC-*)

    # Append the address to the ADDRESSES array
    ADDRESSES+=("$ADDRESS")
    echo "Loaded 0xAddress for validator $i: $ADDRESS"


        # Append the JSON entry to the ADDRESSES_JSON array
    ADDRESSES_JSON+=(" \"$ADDRESS\": { \"balance\": \"$VALIDATOR_BALANCE\" },")

done

# Print all loaded addresses
echo "All loaded 0xAddresses:"
for address in "${ADDRESSES[@]}"; do
    echo "$address"
done



# Function to generate extra data
generate_extra_data() {
    local extra_data="0x$(printf '%064x' 0)"
    for address in "${ADDRESSES[@]}"; do
        extra_data+="${address#0x}"
    done
    # extra_data+="$(printf '__ADDRESS__')"
    extra_data+="$(printf '%0130x' 0)"
    echo "$extra_data"
}

# Generate genesis file
inject_genesis() {
    local balance="0x21e19e0c9bab240000000"
    local gas_limit="0x1c9c380"  # Replace with your desired gas limit
    local extra_data=$(generate_extra_data)

    awk -v balance="$balance" \
        -v chain_id="$CHAIN_ID" \
        -v gas_limit="$gas_limit" \
        -v address_alloc="$(echo "${ADDRESSES_JSON[*]}")" \
        -v extra_data="$extra_data" '
    BEGIN {
        FS = OFS = ""

    }
    {
        gsub(/__CHAIN_ID__/, chain_id)
        gsub(/__GAS_LIMIT__/, gas_limit)
        gsub(/__EXTRA_DATA__/, extra_data)
        gsub(/__ALLOC__/, address_alloc)
    }
    { print }
    ' "$GENESIS_TEMPLATE" > "$GENESIS_OUTPUT"
}


inject_genesis

echo "Genesis file generated at $GENESIS_OUTPUT"


# Create consensus genesis file (needs to be done one box)
docker run --user $(id -u):$(id -g) --rm \
    -v "$(pwd)/../config:/config" \
    -v "$(pwd)/../templates/execution_template:/execution_template" \
    -v "$(pwd)/../templates/consensus_template:/consensus_template" \
    gcr.io/prysmaticlabs/prysm/cmd/prysmctl:latest\
    testnet generate-genesis \
    --fork=deneb \
    --num-validators=64 \
    --genesis-time-delay=300 \
    --output-ssz="/consensus_template/tmp-genesis.ssz" \
    --chain-config-file="/consensus_template/config.yml" \
    --geth-genesis-json-in="/execution_template/tmp-genesis.json" \
    --geth-genesis-json-out="/execution_template/tmp-genesis.json"

echo "Beacon chain genesis created and output at $GENESIS_SZZ_OUTPUT"

# Copy the genesis file into the validator execution directory
echo "Copy Genesis file generated at $GENESIS_OUTPUT"
for i in $(seq 1 $NUM_VALIDATORS); do

    # Define the keystore path
    VALIDATOR_CONSENSUS_DIR="$CONFIG_DIR/validator_$i/consensus"
    VALIDATOR_EXECUTION_DIR="$CONFIG_DIR/validator_$i/execution"
    mkdir -p "$VALIDATOR_CONSENSUS_DIR"

    cp "$GENESIS_OUTPUT" "$VALIDATOR_EXECUTION_DIR/genesis.json"
    cp "$GENESIS_SZZ_OUTPUT" "$VALIDATOR_CONSENSUS_DIR/genesis.ssz"
    cp "$CONSENSUS_TEMPLATE_CONFIG" "$VALIDATOR_CONSENSUS_DIR/"
    
done

# remove genesis working file
rm "$GENESIS_SZZ_OUTPUT"
rm "$GENESIS_OUTPUT"