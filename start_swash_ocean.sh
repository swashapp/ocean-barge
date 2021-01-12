#!/bin/bash
#set -x

# Using this script to run barge without Contract and Ganache containers dependency
# Following variables are important for Swash
export OCEAN_HOME=''
export CONTRACT_VERSION=''
export CONTRACTS_NETWORK_NAME=''
export EVENTS_RPC=''
export ALLOWED_PUBLISHERS=''
export BFACTORY_BLOCK=''
export METADATA_CONTRACT_BLOCK=''
export PROVIDER_ADDRESS=''
export PROVIDER_PASSWORD=''

git clone https://github.com/oceanprotocol/contracts.git data/ocean-contracts

cd data/ocean-contracts
git checkout ${CONTRACT_VERSION}

cd ../..

bash start_ocean.sh --no-ganache --no-dashboard --skip-deploy
