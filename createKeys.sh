#!/usr/bin/env bash

# Exit script on error
set -e
basedir=$(cd `dirname $0`; pwd)
workspace=${basedir}

function vnode() {
    mkdir -p newkeys
    
    for ((i = 0; i < Number; i++)); do
        ${workspace}/bin/geth account new --datadir ./newkeys/validator$i --password ${workspace}/keys/password.txt
        ${workspace}/bin/bootnode -genkey ./newkeys/validator-nodekey$i
    done
}

function bls() {
    mkdir -p newkeys

    for ((i = 0; i < Number; i++)); do
        ${workspace}/bin/geth bls account new --datadir ./newkeys/bls$i --blspassword ${workspace}/keys/password.txt
    done
}

function sentry() {
    mkdir -p newkeys
    
    for ((i = 0; i < Number; i++)); do
        ${workspace}/bin/bootnode -genkey ./newkeys/sentry-nodekey$i
    done
}

CMD=$1
Number=$2

case ${CMD} in
vnode)
    echo "===== vnode ===="
    vnode
    echo "===== end ===="
    ;;
bls)
    echo "===== bls ===="
    bls
    echo "===== end ===="
    ;;
sentry)
    echo "===== sentry ===="
    sentry
    echo "===== end ===="
    ;;
clean)
    echo "===== clean ===="
    rm -rf newkeys
    echo "===== end ===="
    ;;    
*)
    echo "Usage: createKeys.sh [vnode|bls|sentry|clean] [number]"
    echo "like: createKeys.sh vnode 3, it will create accounts"
    ;;
esac