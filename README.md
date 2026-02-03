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

## 替换节点的P2P地址
replaceP2P.sh 0 127.0.0.1:30314 172.31.25.65:30311

geth bls account list --datadir ${DATA_DIR}

查看对应 enode
bootnode -nodekey sentry-nodekey -writeaddress

## 注意事项（⚠️ 很重要）
1.nodekey 不能泄露
2.泄露 = 节点身份被劫持
3.一对 sentry / validator 通常固定 nodekey
4.不能多个节点共用同一个 nodekey
5.BSC 与 ETH nodekey 规则完全一致（secp256k1）

## 常见问题
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

## 获取节点1的enode信息
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


## 修改最低的gas price，需要修改以下文件：
1. config.toml
### config.toml参数说明
参数	       核心作用
PriceLimit	交易能不能进池子的最低门槛
GasPrice	  节点默认使用的 gas 单价
Recommit	  验证者多久重新打包一次区块（10000000000 10秒）
2. bsc/eth/gasprice/gasprice.go DefaultMaxPrice
DefaultMaxPrice    = big.NewInt(190476190480)
3. 修改验证节点需要的质押数量合约
bsc/core/systemcontracts/fermi/rialto/StakeHubContract


sed -i "s/PriceLimit = 1000000000000/PriceLimit = 190476190480/g" .local/node0/config.toml
sed -i "s/GasPrice = 1000000000000/GasPrice = 190476190480/g" .local/node0/config.toml

sed -i "s/PriceLimit = 1000000000000/PriceLimit = 190476190480/g" .local/node1/config.toml
sed -i "s/GasPrice = 1000000000000/GasPrice = 190476190480/g" .local/node1/config.toml

sed -i "s/PriceLimit = 1000000000000/PriceLimit = 190476190480/g" .local/node2/config.toml
sed -i "s/GasPrice = 1000000000000/GasPrice = 190476190480/g" .local/node2/config.toml

sed -i "s/PriceLimit = 1000000000000/PriceLimit = 190476190480/g" .local/node3/config.toml
sed -i "s/GasPrice = 1000000000000/GasPrice = 190476190480/g" .local/node3/config.toml

## 多服务器多节点部署指引

1. 更改链id及初始持币地址
链id涉及文件如下：
.env
config.toml
bsc/eth/handler.go
bsc/params/config.go

初始持币涉及文件如下：
.env
config.toml
bsc-genesis-contract/package.json

注：更改后需要重新构建geth
make geth

2. 生成相关的key

修改密码：vi ./keys/password.txt
./createKeys vnode 9
./createKeys bls 9
./createKeys sentry 9

cp -r ./keys/password.txt ./newkeys/
rm -rf ./keys
mv newkeys keys

3. 生成创世区块文件
./bsc_cluster.sh genGenesis

4. 修改初始化持币数量（initAmt）
vi genesis/genesis.json

totalAmt:= 0x33b2e3c9fd0803ce8000000 //10亿
initAmt:= 0x33b2c8aba00373f55700000 //10亿-8004
validatorsTotalAmt:= 0x1b1e5d048fd92900000 //8004
validatorAmt:= 0x6c7974123f64a40000 //2001

5. 初始化整个网络
./bsc_cluster.sh initNetwork

6. 更改p2p的通信地址（enode）

sed -i "s/127.0.0.1:30312/13.215.179.62:30311/g" .local/node0/config.toml
sed -i "s/127.0.0.1:30313/13.229.207.113:30311/g" .local/node0/config.toml
sed -i "s/127.0.0.1:30314/52.77.249.240:30311/g" .local/node0/config.toml

sed -i "s/127.0.0.1:30311/3.0.103.147:30311/g" .local/node1/config.toml
sed -i "s/127.0.0.1:30313/13.229.207.113:30311/g" .local/node1/config.toml
sed -i "s/127.0.0.1:30314/52.77.249.240:30311/g" .local/node1/config.toml

sed -i "s/127.0.0.1:30311/3.0.103.147:30311/g" .local/node2/config.toml
sed -i "s/127.0.0.1:30312/13.215.179.62:30311/g" .local/node2/config.toml
sed -i "s/127.0.0.1:30314/52.77.249.240:30311/g" .local/node2/config.toml

sed -i "s/127.0.0.1:30311/3.0.103.147:30311/g" .local/node3/config.toml
sed -i "s/127.0.0.1:30312/13.215.179.62:30311/g" .local/node3/config.toml
sed -i "s/127.0.0.1:30313/13.229.207.113:30311/g" .local/node3/config.toml


sed -i 's/ListenAddr = ":303[0-9]*"/ListenAddr = ":30311"/' .local/node1/config.toml
sed -i 's/ListenAddr = ":303[0-9]*"/ListenAddr = ":30311"/' .local/node2/config.toml
sed -i 's/ListenAddr = ":303[0-9]*"/ListenAddr = ":30311"/' .local/node3/config.toml

7. 拷贝节点信息及上传到其它服务器

rm -rf newnode*
./copyNode.sh vnode 1 0
tar -czvf newnode.tar.gz newnode
scp newnode.tar.gz root@13.215.179.62:/data/


rm -rf newnode*
./copyNode.sh vnode 2 0
tar -czvf newnode.tar.gz newnode
scp newnode.tar.gz root@13.229.207.113:/data/

rm -rf newnode*
./copyNode.sh vnode 3 0
tar -czvf newnode.tar.gz newnode
scp newnode.tar.gz root@52.77.249.240:/data/

8. 启动各个节点
节点1：./bsc_cluster.sh start 0
节点2：./startNode.sh start 0
节点3：./startNode.sh start 0
节点4：./startNode.sh start 0

9. 质押成为验证者节点

./startNode.sh stake 0 http://3.0.103.147:8545 0

./startNode.sh stake 0 http://3.0.103.147:8545 1

./startNode.sh stake 0 http://3.0.103.147:8545 2

./startNode.sh stake 0 http://3.0.103.147:8545 3

10. 链源代码更改后，拷贝到各个服务器重新启动各节点

scp ./build/bin/geth root@13.215.179.62:/data/newnode/
scp ./build/bin/geth root@13.229.207.113:/data/newnode/
scp ./build/bin/geth root@52.77.249.240:/data/newnode/

节点1：
./bsc_cluster.sh stop 0
./bsc_cluster.sh start 0

节点2：./startNode.sh restart 0
节点3：./startNode.sh restart 0
节点4：./startNode.sh restart 0