#!/usr/bin/env bash

# Exit script on error
set -e

function vnode() {
    rm -rf newnode
    mkdir -p newnode/.local/node$ToIdx/geth
    mkdir -p newnode/.local/node0
    mkdir -p newnode/bin/
    #mkdir -p newnode/keys/

    cp .env newnode/
    cp startNode.sh newnode/
    cp bin/geth newnode/bin/

    cp ./create-validator/create-validator newnode/bin/
    #cp -r ./keys/validator${FromIdx} newnode/keys/validator${ToIdx}

    cp .local/node0/hardforkTime.txt newnode/.local/node0/
    cp .local/node0/init.log newnode/.local/node0/

    cp -r .local/node$FromIdx/bls newnode/.local/node$ToIdx/
    cp .local/node$FromIdx/config.toml newnode/.local/node$ToIdx/
    cp .local/node$FromIdx/genesis.json newnode/.local/node$ToIdx/
    cp .local/node$FromIdx/geth/nodekey newnode/.local/node$ToIdx/geth/
    #节点运行时会自动创建geth.ipc
 #   cp -r .local/node$FromIdx/geth.ipc newnode/.local/node$ToIdx/
    
    cp -r .local/node$FromIdx/keystore newnode/.local/node$ToIdx/
    cp .local/node$FromIdx/password.txt newnode/.local/node$ToIdx/
    cp -r .local/node$FromIdx/voteJournal newnode/.local/node$ToIdx/
}

function fullnode() {
    rm -rf fullnode
    mkdir -p ./fullnode/.local/node$ToIdx/geth/
    mkdir -p ./fullnode/bin/

    cp bin/geth ./fullnode/bin/
    cp bsc_fullnode.sh ./fullnode/
    cp .env ./fullnode/
    cp keys/fullnode-nodekey$FromIdx ./fullnode/.local/node$ToIdx/geth/nodekey
    cp .local/node$FromIdx/hardforkTime.txt ./fullnode/.local/node$ToIdx/
    cp .local/node$FromIdx/init.log ./fullnode/.local/node$ToIdx/
    cp .local/node$FromIdx/config.toml ./fullnode/.local/node$ToIdx/
    cp .local/node$FromIdx/genesis.json ./fullnode/.local/node$ToIdx/
}

CMD=$1
FromIdx=$2
ToIdx=$3

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
    echo "Usage: copyNode.sh vnode|fullnode fromNodeIndex toNodeIndex"
    echo "like: copyNode.sh vnode 3 0, it will copy a config of node3"
    ;;
esac