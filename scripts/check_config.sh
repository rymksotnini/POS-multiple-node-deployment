#!/bin/bash

# Configuration variables
CONFIG_DIR="../config"
KEYSTORE_DIR="$(pwd)/$CONFIG_DIR"
NUM_VALIDATORS=3

# Variable to track the success or failure of checks
all_checks_passed=true

check_file() {
    if [[ -f "$1" && -s "$1" ]]; then
        return 0  # File exists and is not empty
    else
        return 1  # File is missing or empty
    fi
}

check_directory() {
    if [[ ! -d "$1" ]]; then
        return 1  # Directory is missing
    fi
    result=$(sudo ls -A "$1")
    if [[ -n "$result" ]]; then
        return 0  # Directory exists and is not empty
    else
        return 1  # Directory is empty
    fi
}


# Loop through each validator directory to check files
for i in $(seq 1 $NUM_VALIDATORS); do
    # Define paths for each validator
    VALIDATOR_DIR="$KEYSTORE_DIR/validator_$i"
    EXECUTION_DIR="$VALIDATOR_DIR/execution"
    PASSWORD_FILE="$EXECUTION_DIR/password.txt"
    JWT_FILE="$VALIDATOR_DIR/jwt.hex"
    BEACON_KEY_FILE="$VALIDATOR_DIR/beacon_node_key"
    EXEC_KEYSTORE_DIR="$VALIDATOR_DIR/execution/keystore"

    # Check directories and files
    check_directory "$VALIDATOR_DIR" || all_checks_passed=false
    check_directory "$EXECUTION_DIR" || all_checks_passed=false
    check_directory "$EXEC_KEYSTORE_DIR" || all_checks_passed=false
    check_file "$PASSWORD_FILE" || all_checks_passed=false
    check_file "$JWT_FILE" || all_checks_passed=false
    check_file "$BEACON_KEY_FILE" || all_checks_passed=false
done

if [ "$all_checks_passed" = true ]; then
    echo "true"
    exit 0  # Success
else
    echo "false"
    exit 1  # Failure
fi
