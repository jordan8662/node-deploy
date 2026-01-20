#!/usr/bin/env bash

# Exit script on error
set -e

basedir=$(
    cd $(dirname $0)
    pwd
)
workspace=${basedir}

function init() {
    echo "----replace----"

    sed -i "s/$FromAddr/$ToAddr/g" ${workspace}/.local/node$NodeIdx/config.toml
 
    echo "----end----"
}

NodeIdx=$1
FromAddr=$2
ToAddr=$3

echo "Usage: replaceP2P.sh [node index] [from] [to]"
echo "example: replaceP2P.sh 0 127.0.0.1:30314 172.31.25.65:30311"

init