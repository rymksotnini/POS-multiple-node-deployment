#!/bin/bash

cd $(dirname $0)

if [ ! -f ../bootnode/bootnode.key ]; then
    echo "Bootnode key not found. Please run the setup script first."
    exit 1
fi


PUBLIC_KEY=$(docker run --rm -v $(pwd)/../bootnode:/bootnode ethereum/client-go:alltools-latest \
  bootnode -nodekey /bootnode/bootnode.key -writeaddress)

echo "Public Key: $PUBLIC_KEY"

echo "Warning: this script does not actually generate an ENR, so it has been disabled."