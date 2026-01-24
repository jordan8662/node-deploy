#!/usr/bin/env bash

# Exit script on error
set -e

basedir=$(
    cd $(dirname $0)
    pwd
)
workspace=${basedir}
source ${workspace}/.env
gcmode="full"
sleepBeforeStart=15
sleepAfterStart=10

# stop geth client
function exit_previous() {
    echo "----exit----"
    echo ${workspace}
    ValIdx=$1
    echo "geth${ValIdx}"
    ps -ef  | grep geth$ValIdx | grep config |awk '{print $2}' | xargs -r kill
    sleep ${sleepBeforeStart}
}

function init() {
    echo "----init----"
    ValIdx=$1
    #初创建共识节点的ip地址
    ConsIp=$2
    #sed -i "s/^127.0.0.1:303$/$ConsIp:303/" ${workspace}/.local/node$ValIdx/config.toml
    sed -i "s/127.0.0.1:303/$ConsIp:303/g" ${workspace}/.local/node$ValIdx/config.toml
    sed -i 's/ListenAddr = ":303[0-9]*"/ListenAddr = ":30311"/' ${workspace}/.local/node$ValIdx/config.toml

    ${workspace}/bin/geth init --state.scheme path --datadir ${workspace}/.local/node$ValIdx/ ${workspace}/.local/node$ValIdx/genesis.json

    sleep ${sleepAfterStart}

    echo "----end----"
}

function start_node() {
    local type=$1       # node | sentry | full
    local idx=$2        # index (validator/sentry)，full default 0
    local datadir=$3
    local geth_bin=$4
    local cons_addr=$5
    local http_port=$6
    local ws_port=$7
    local metrics_port=$8
    local pprof_port=$9

    # update `config` in genesis.json
    # ${workspace}/.local/node${i}/geth${i} dumpgenesis --datadir ${workspace}/.local/node${i} | jq . > ${workspace}/.local/node${i}/genesis.json
    nohup ${geth_bin} --config ${datadir}/config.toml \
        --datadir ${datadir} \
        --nodekey ${datadir}/geth/nodekey \
        --rpc.allow-unprotected-txs --allow-insecure-unlock \
        --ws --ws.addr 0.0.0.0 --ws.port ${ws_port} \
        --http --http.addr 0.0.0.0 --http.port ${http_port} --http.corsdomain "*" \
        --metrics --metrics.addr localhost --metrics.port ${metrics_port} \
        --pprof --pprof.addr localhost --pprof.port ${pprof_port} \
        --gcmode ${gcmode} --syncmode full --monitor.maliciousvote \
        --rialtohash ${rialtoHash} \
        --override.passedforktime ${PassedForkTime} \
        --override.lorentz ${PassedForkTime} \
        --override.maxwell ${PassedForkTime} \
        --override.fermi ${LastHardforkTime} \
        --override.immutabilitythreshold ${FullImmutabilityThreshold} \
        --override.breatheblockinterval ${BreatheBlockInterval} \
        --override.minforblobrequest ${MinBlocksForBlobRequests} \
        --override.defaultextrareserve ${DefaultExtraReserveForBlobRequests} \
        $( [ "${type}" = "node" ] && echo "--mine --vote --unlock ${cons_addr} --miner.etherbase ${cons_addr} --password ${datadir}/password.txt --blspassword ${datadir}/password.txt" ) \
        >> ${datadir}/bsc-node.log 2>&1 &
}

function native_start() {
    PassedForkTime=`cat ${workspace}/.local/node0/hardforkTime.txt|grep passedHardforkTime|awk -F" " '{print $NF}'`
    LastHardforkTime=$(expr ${PassedForkTime} + ${LAST_FORK_MORE_DELAY})
    rialtoHash=`cat ${workspace}/.local/node0/init.log|grep "database=chaindata"|awk -F"=" '{print $NF}'|awk -F'"' '{print $1}'`

    i=$1
    datadir="${workspace}/.local/node${i}"

    # get validator address
    cons_addr="0x$(jq -r .address ${datadir}/keystore/*)"

    cp ${workspace}/bin/geth ${datadir}/geth${i}

    base=$((8545 + i*2))
    start_node "node" $i $datadir "${datadir}/geth${i}" "${cons_addr}" \
        $base $base $((6060+i*2)) $((7060+i*2))

    sleep ${sleepAfterStart}
}

function register_stakehub(){
    # stakehub wait feynman enable 
    ${workspace}/bin/create-validator --consensus-key-dir ${workspace}/.local/node$ValidatorIdx --vote-key-dir ${workspace}/.local/node$ValidatorIdx \
            --password-path ${workspace}/.local/node$ValidatorIdx/password.txt --amount 1501 --validator-desc Val${VnodeIdx} --rpc-url ${ConsIp}
}


CMD=$1
ValidatorIdx=$2
ConsIp=$3
VnodeIdx=$4
case ${CMD} in
stop)
    exit_previous $ValidatorIdx
    ;;
start)
    init $ValidatorIdx $ConsIp
    native_start $ValidatorIdx
    ;;
restart)
    exit_previous $ValidatorIdx
    native_start $ValidatorIdx
    ;;
stake)
    register_stakehub
    ;;
*)
    echo "Usage: startNode.sh stop [vidx]| start [vidx] [ip]| restart [vidx]"
    echo "example: startNode.sh start 3 172.31.27.118"
    echo "example: startNode.sh stake toIdx rpcUrl fromIdx"
    ;;
esac
