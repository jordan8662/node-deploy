package main

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts"
	"github.com/ethereum/go-ethereum/accounts/keystore"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	validatorpb "github.com/prysmaticlabs/prysm/v5/proto/prysm/v1alpha1/validator-client"
	"github.com/prysmaticlabs/prysm/v5/validator/accounts/iface"
	"github.com/prysmaticlabs/prysm/v5/validator/accounts/wallet"
	"github.com/prysmaticlabs/prysm/v5/validator/keymanager"

	"create-validator/abi"
)

var (
	valDescription  = flag.String("validator-desc", "test-val", "validator description")
	amount          = flag.Int("amount", 2001, "amount of PETH to delegate")
	rpcUrl          = flag.String("rpc-url", "http://127.0.0.1:8545", "rpc url")
	consensusKeyDir = flag.String("consensus-key-dir", "", "consensus keys dir")
	voteKeyDir      = flag.String("vote-key-dir", "", "vote keys dir")
	passwordPath    = flag.String("password-path", "", "password dir")
)

func main() {
	flag.Parse()

	if *consensusKeyDir == "" {
		panic("consensus-keys-dir is required")
	}
	if *voteKeyDir == "" {
		panic("vote-keys-dir is required")
	}
	if *passwordPath == "" {
		panic("password-path is required")
	}

	client, err := ethclient.Dial(*rpcUrl)
	if err != nil {
		panic(err)
	}

	bz, err := os.ReadFile(*passwordPath)
	if err != nil {
		panic(err)
	}
	password := string(bytes.TrimSpace(bz))

	consensusKs := keystore.NewKeyStore(*consensusKeyDir+"/keystore", keystore.StandardScryptN, keystore.StandardScryptP)
	consensusAddr := consensusKs.Accounts()[0].Address
	consensusAcc := accounts.Account{Address: consensusAddr}
	err = consensusKs.Unlock(consensusAcc, password)
	if err != nil {
		panic(err)
	}

	voteKm, err := getBlsKeymanager(*voteKeyDir+"/bls/wallet", password)
	if err != nil {
		panic(err)
	}

	ctx := context.Background()

	pubkeys, err := voteKm.FetchValidatingPublicKeys(ctx)
	if err != nil {
		panic(err)
	}
	pubKey := pubkeys[0]

	delegation := new(big.Int).Mul(big.NewInt(int64(*amount)), big.NewInt(1e18)) // 5000000 PETH
	description := abi.StakeHubDescription{
		Moniker:  *valDescription,
		Identity: *valDescription,
		Website:  *valDescription,
		Details:  *valDescription,
	}
	commission := abi.StakeHubCommission{
		Rate:          100,
		MaxRate:       1000,
		MaxChangeRate: 100,
	}

	chainId, err := client.ChainID(ctx)
	if err != nil {
		panic(err)
	}
	paddedChainIdBytes := make([]byte, 32)
	copy(paddedChainIdBytes[32-len(chainId.Bytes()):], chainId.Bytes())

	msgHash := crypto.Keccak256(append(consensusAddr.Bytes(), append(pubKey[:], paddedChainIdBytes...)...))
	req := validatorpb.SignRequest{
		PublicKey:   pubKey[:],
		SigningRoot: msgHash,
	}
	proof, err := voteKm.Sign(ctx, &req)
	if err != nil {
		panic(err)
	}

	stakeHubAbi, err := abi.StakeHubMetaData.GetAbi()
	if err != nil {
		panic(err)
	}
	method := "createValidator"
	data, err := stakeHubAbi.Pack(method, consensusAddr, pubKey[:], proof.Marshal(), commission, description)
	if err != nil {
		panic(err)
	}

	nonce, err := client.PendingNonceAt(ctx, consensusAddr)
	if err != nil {
		panic(err)
	}
	gasPrice, err := client.SuggestGasPrice(ctx)
	if err != nil {
		panic(err)
	}
	stakeHubAddr := common.HexToAddress("0x0000000000000000000000000000000000002002")
	tx := types.NewTx(&types.LegacyTx{
		Nonce:    nonce,
		To:       &stakeHubAddr,
		Value:    delegation,
		Gas:      2000000,
		GasPrice: gasPrice,
		Data:     data,
	})

	// 编码函数调用数据
	queryData, err := stakeHubAbi.Pack("minSelfDelegationBNB")
	if err != nil {
		fmt.Println(fmt.Errorf("编码函数调用失败: %v", err))
		return
	}

	// 调用合约方法
	result, err := client.CallContract(ctx, ethereum.CallMsg{
		To:   &stakeHubAddr,
		Data: queryData,
	}, nil) // nil表示最新区块

	if err != nil {
		fmt.Println(fmt.Errorf("合约调用失败: %v", err))
		return
	}

	// 解码返回值
	queryOut, err := stakeHubAbi.Unpack("minSelfDelegationBNB", result)
	if err != nil {
		fmt.Println(fmt.Errorf("解码返回值失败: %v", err))
		return
	}
	fmt.Println(fmt.Errorf("queryOut: %v", queryOut))

	if 2 > 1 {
		return
	}

	signedTx, err := consensusKs.SignTx(consensusAcc, tx, chainId)
	if err != nil {
		panic(err)
	}

	err = client.SendTransaction(ctx, signedTx)
	if err != nil {
		panic(err)
	}

	fmt.Println("send createValidator. Tx hash:", signedTx.Hash().Hex())

	// 等待交易确认
	receipt, err := waitForTransactionReceipt(client, ctx, signedTx.Hash())
	if err != nil {
		fmt.Println(fmt.Errorf("等待交易确认失败: %v", err))
		return
	}

	// 检查交易状态
	if receipt.Status == 0 {
		// 交易失败，尝试获取revert原因
		revertReason, err := getTransactionRevertReason(client, ctx, consensusAddr, signedTx, receipt)
		if err != nil {
			fmt.Println(fmt.Errorf("交易失败，但无法获取revert原因: %v", err))
		}
		fmt.Println(fmt.Errorf("revertReason: %v", revertReason))
	}
}

// 方法2：从错误中提取revert原因
func extractRevertReason(err error) (string, error) {
	errStr := err.Error()

	// 检查是否包含revert数据
	if strings.Contains(errStr, "execution reverted") {
		// 尝试解析十六进制数据
		parts := strings.Split(errStr, "0x")
		if len(parts) > 1 {
			hexData := "0x" + parts[len(parts)-1]
			return decodeRevertData(hexData)
		}
	}

	return "", fmt.Errorf("未找到revert原因")
}

// 方法3：解码revert数据
func decodeRevertData(hexData string) (string, error) {
	data := common.FromHex(hexData)

	// 检查是否为标准的Error(string)
	if len(data) >= 4 && string(data[:4]) == "\x08\xc3\x79\xa0" { // Error(string)的selector
		if len(data) > 36 { // 4字节selector + 32字节偏移量 + 数据
			// 解析字符串长度和内容
			strLen := new(big.Int).SetBytes(data[36:68]).Uint64()
			if len(data) >= int(68+strLen) {
				strData := data[68 : 68+strLen]
				return string(strData), nil
			}
		}
	}

	// 检查是否为Panic(uint256)
	if len(data) >= 4 && string(data[:4]) == "\x4e\x48\x7b\x71" { // Panic(uint256)的selector
		if len(data) >= 36 {
			panicCode := new(big.Int).SetBytes(data[4:36]).Uint64()
			return fmt.Sprintf("Panic with code %d", panicCode), nil
		}
	}

	// 返回原始十六进制数据
	return fmt.Sprintf("Unknown revert data: %s", hexData), nil
}

// 方法4：通过debug_traceTransaction获取详细错误信息
func getTransactionRevertReason(
	client *ethclient.Client,
	ctx context.Context,
	from common.Address,
	tx *types.Transaction,
	receipt *types.Receipt,
) (string, error) {
	// 如果节点支持debug_traceTransaction，可以获取更详细的信息
	// 注意：这通常需要Archive节点或本地节点的支持

	// 使用Call模拟交易来获取revert原因
	msg := ethereum.CallMsg{
		From:     from,
		To:       tx.To(),
		Gas:      tx.Gas(),
		GasPrice: tx.GasPrice(),
		Value:    tx.Value(),
		Data:     tx.Data(),
	}

	_, err := client.CallContract(ctx, msg, receipt.BlockNumber)
	if err != nil {
		return extractRevertReason(err)
	}

	return "", nil
}

// 等待交易确认
func waitForTransactionReceipt(
	client *ethclient.Client,
	ctx context.Context,
	txHash common.Hash,
) (*types.Receipt, error) {
	for {
		receipt, err := client.TransactionReceipt(ctx, txHash)
		if err != nil {
			if err.Error() == "not found" {
				// 交易尚未被打包，继续等待
				continue
			}
			return nil, err
		}
		return receipt, nil
	}
}

func getBlsKeymanager(walletPath, password string) (keymanager.IKeymanager, error) {
	w, err := wallet.OpenWallet(context.Background(), &wallet.Config{
		WalletDir:      walletPath,
		WalletPassword: password,
	})
	if err != nil {
		panic(err)
	}

	km, err := w.InitializeKeymanager(context.Background(), iface.InitKeymanagerConfig{ListenForChanges: false})
	if err != nil {
		panic(err)
	}

	return km, nil
}
