#!/bin/bash

SEED="bootnode_seed"  # You can modify this seed as needed

# Create directory for bootnode
mkdir -p $(pwd)/../bootnode

# Generate the bootnode key using a seed
echo -n "$SEED" | openssl dgst -sha256 -binary | xxd -p -c 32 > $(pwd)/../bootnode/bootnode.key

# Get the bootnode ID (public key)
BOOTNODE_ID=$(docker run --rm -v $(pwd)/../bootnode:/bootnode ethereum/client-go:alltools-latest \
  bootnode -nodekey /bootnode/bootnode.key -writeaddress)

# Display the bootnode ID
echo "Your Bootnode ID is:"
echo $BOOTNODE_ID

# Generate the enode URL
ENODE_URL="enode://$BOOTNODE_ID@bootnode:30301"
echo "Your bootnode enode URL is (replace <YOUR_BOOTNODE_IP> with the actual IP):"
echo $ENODE_URL

# Update .env file
ENV_FILE=$(pwd)/../.env
if [ -f "$ENV_FILE" ]; then
    # Use temporary file for sed operations
    TMP_FILE=$(mktemp)

    # Update or append BOOTNODE_ID
    if grep -q "^BOOTNODE_ID=" "$ENV_FILE"; then
        sed "s|^BOOTNODE_ID=.*|BOOTNODE_ID=$BOOTNODE_ID|" "$ENV_FILE" > "$TMP_FILE"
    else
        echo "BOOTNODE_ID=$BOOTNODE_ID" >> "$TMP_FILE"
    fi

    # Update or append BOOTNODE_ENODE
    if grep -q "^BOOTNODE_ENODE=" "$ENV_FILE"; then
        sed "s|^BOOTNODE_ENODE=.*|BOOTNODE_ENODE=$ENODE_URL|" "$TMP_FILE" > "${TMP_FILE}.2" && mv "${TMP_FILE}.2" "$TMP_FILE"
    else
        echo "BOOTNODE_ENODE=$ENODE_URL" >> "$TMP_FILE"
    fi

    # Replace original .env with updated content
    mv "$TMP_FILE" "$ENV_FILE"
else
    echo "BOOTNODE_ID=$BOOTNODE_ID" > "$ENV_FILE"
    echo "BOOTNODE_ENODE=$ENODE_URL" >> "$ENV_FILE"
fi

echo "Bootnode information has been saved to .env file."
echo "Remember to replace <YOUR_BOOTNODE_IP> in the .env file with your actual bootnode IP address."