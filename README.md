# Deployment tools of BSC


## Installation
Before proceeding to the next steps, please ensure that the following packages and softwares are well installed in your local machine: 
- nodejs: v16.15.0
- npm: 6.14.6
- go: 1.24+
- foundry
- python3 3.12.x
- poetry
- jq


## Quick Start
1. Clone this repository
```bash
git clone https://github.com/bnb-chain/node-deploy.git
```

2. For the first time, please execute the following command
```bash
pip3 install -r requirements.txt
```

3. build `create-validator`

```bash
# This tool is used to register the validators into StakeHub.
cd create-validator
go build
```

4. Configure the cluster
```
  You can configure the cluster by modifying the following files:
   - `config.toml`
   - `genesis/genesis-template.json`
   - `genesis/scripts/init_holders.template`
   - `.env`
```

5. Setup all nodes.
two different ways, choose as you like.
```bash
bash -x ./bsc_cluster.sh reset # will reset the cluster and start
# The 'vidx' parameter is optional. If provided, its value must be in the range [0, ${BSC_CLUSTER_SIZE}). If omitted, it affects all clusters.
bash -x ./bsc_cluster.sh stop [vidx] # Stops the cluster
bash -x ./bsc_cluster.sh start [vidx] # only start the cluster
bash -x ./bsc_cluster.sh restart [vidx] # start the cluster after stopping it
```

6. Setup a full node.
If you want to run a full node to test snap/full syncing, you can run:

> Attention: it relies on the validator cluster, so you should set up validators by `bsc_cluster.sh` firstly.

```bash
# reset a full sync node0
bash +x ./bsc_fullnode.sh reset 0 full
# reset a snap sync node1
bash +x ./bsc_fullnode.sh reset 1 snap
# restart the snap sync node1
bash +x ./bsc_fullnode.sh restart 1 snap
# stop the snap sync node1
bash +x ./bsc_fullnode.sh stop 1 snap
# clean the snap sync node1
bash +x ./bsc_fullnode.sh clean 1 snap
# reset a full sync node as fast node
bash +x ./bsc_fullnode.sh reset 2 full "--tries-verify-mode none"
# reset a snap sync node with prune ancient
bash +x ./bsc_fullnode.sh reset 3 snap "--pruneancient"
```

You can see the logs in `.local/fullnode`.

Generally, you need to wait for the validator to produce a certain amount of blocks before starting the full/snap syncing test, such as 1000 blocks.

## Background transactions
```bash
## normal tx
cd txbot
go build
./air-drops

## blob tx
cd txblob
go build
./txblob
```

## 拷贝验证节点或全节点的配置
```bash
./copyNode.sh vnode 3
tar -czvf newnode.gar.gz newnode
or
./copyNode.sh fullnode 0
tar -czvf fullnode.gar.gz fullnode
```
### 全节点的部署依赖于bsc_cluster.sh部署的验证节点

## 替换节点的P2P地址
replaceP2P.sh 0 127.0.0.1:30314 172.31.25.65:30311

## 启动验证节点
```bash
./startNode.sh start 3 172.31.27.118
```

geth account new --datadir ./validator-account/validator0
geth account new --datadir ./validator-account/validator1
geth account new --datadir ./validator-account/validator2
geth account new --datadir ./validator-account/validator3

geth bls account new --datadir ./bls-account/bls0

geth bls account list --datadir ${DATA_DIR}

bootnode -genkey ./sentry/sentry-nodekey0
bootnode -genkey ./sentry/sentry-nodekey1
bootnode -genkey ./sentry/sentry-nodekey2
bootnode -genkey ./sentry/sentry-nodekey3


bootnode -genkey ./validator/validator-nodekey0
bootnode -genkey ./validator/validator-nodekey1
bootnode -genkey ./validator/validator-nodekey2
bootnode -genkey ./validator/validator-nodekey3

查看对应 enode
bootnode -nodekey sentry-nodekey -writeaddress

### 注意事项（⚠️ 很重要）
1.nodekey 不能泄露
2.泄露 = 节点身份被劫持
3.一对 sentry / validator 通常固定 nodekey
4.不能多个节点共用同一个 nodekey
5.BSC 与 ETH nodekey 规则完全一致（secp256k1）

### 常见问题
Q：nodekey 是不是和钱包私钥一样？
❌ 不是
✔ 只是 P2P 网络身份私钥，不控制资产
Q：能不能随机生成 64 位 hex？
❌ 不建议
✔ 必须是 secp256k1 合法私钥（bootnode/geth 会保证）

初始化子模块
git submodule update --init --recursive genesis

拉取子模块的最新更改
git submodule update --remote

### 获取节点1的enode信息
./bin/geth --exec 'admin.nodeInfo.enode' attach .local/node0/geth.ipc

./bin/geth \
  --datadir node2 \
  --syncmode 'full' \
  --port 30312 \
  --http \
  --http.addr '0.0.0.0' \
  --http.port 8547 \
  --http.api 'personal,eth,net,web3,txpool,miner' \
  --ws \
  --ws.addr '0.0.0.0' \
  --ws.port 8548 \
  --ws.api 'personal,eth,net,web3,txpool,miner' \
  --networkid 12345 \
  --nat 'any' \
  --bootnodes 'enode://NODE1_ENODE_HERE@SERVER1_IP:30311' \
  --allow-insecure-unlock \
  --verbosity 3


scp /path/to/local/file.txt username@remote_host:/path/to/remote/directory/


scp fullnode.tar.gz root@172.31.25.65:/root/
