#!/usr/bin/env bash

# Exit script on error
set -e

function vnode() {
    rm -rf newnode
    mkdir -p newnode/.local/node$ValidatorIdx/geth
    mkdir -p newnode/.local/node0
    mkdir -p newnode/bin/

    cp .env newnode/
    cp bin/geth newnode/bin/

    cp .local/node0/hardforkTime.txt newnode/.local/node0/
    cp .local/node0/init.log newnode/.local/node0/

    cp -r .local/node$ValidatorIdx/bls newnode/.local/node$ValidatorIdx/
    cp .local/node$ValidatorIdx/config.toml newnode/.local/node$ValidatorIdx/
    cp .local/node$ValidatorIdx/genesis.json newnode/.local/node$ValidatorIdx/
    cp .local/node$ValidatorIdx/geth/nodekey newnode/.local/node$ValidatorIdx/geth/
    #节点运行时会自动创建geth.ipc
 #   cp -r .local/node$ValidatorIdx/geth.ipc newnode/.local/node$ValidatorIdx/
    
    cp -r .local/node$ValidatorIdx/keystore newnode/.local/node$ValidatorIdx/
    cp .local/node$ValidatorIdx/password.txt newnode/.local/node$ValidatorIdx/
    cp -r .local/node$ValidatorIdx/voteJournal newnode/.local/node$ValidatorIdx/
}

function fullnode() {
    rm -rf fullnode
    mkdir -p ./fullnode/.local/node$ValidatorIdx/geth/
    mkdir -p ./fullnode/bin/

    cp bin/geth ./fullnode/bin/
    cp bsc_fullnode.sh ./fullnode/
    cp .env ./fullnode/
    cp keys/fullnode-nodekey$ValidatorIdx ./fullnode/.local/node$ValidatorIdx/geth/nodekey
    cp .local/node$ValidatorIdx/hardforkTime.txt ./fullnode/.local/node$ValidatorIdx/
    cp .local/node$ValidatorIdx/init.log ./fullnode/.local/node$ValidatorIdx/
    cp .local/node$ValidatorIdx/config.toml ./fullnode/.local/node$ValidatorIdx/
    cp .local/node$ValidatorIdx/genesis.json ./fullnode/.local/node$ValidatorIdx/
}

CMD=$1
ValidatorIdx=$2

case ${CMD} in
vnode)
    echo "===== vnode ===="
    vnode
    echo "===== end ===="
    ;;
    fullnode)
    echo "===== fullnode ===="
    fullnode
    echo "===== end ===="
    ;;
*)
    echo "Usage: copyNode.sh vnode|fullnode nodeIndex"
    echo "like: copyNode.sh vnode 0, it will copy a config of node0"
    ;;
esac