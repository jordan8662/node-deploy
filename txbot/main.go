package main

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"flag"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/params"
)

var (
	account, _ = fromHexKey("59ba8068eb256d520179e903f43dacf6d8d57d72bd306e1bd603fdb8c8da10e8")
	toAddr     = common.HexToAddress("0xDDA23D85E6582c0B0948D7AeC5f3328F8D74c335")

	endpointFlag = flag.String("endpoint", "http://127.0.0.1:8545", "The endpoint of the chain")
	chainIdFlag  = flag.Int64("chainId", 714, "The chainId of the chain")
	chainId      *big.Int
)

func main() {
	flag.Parse()
	chainId = big.NewInt(*chainIdFlag)
	c, _ := ethclient.Dial(*endpointFlag)
	t := time.NewTicker(200 * time.Millisecond)
	for {
		select {
		case <-t.C:
			nonce, err := c.PendingNonceAt(context.Background(), account.addr)
			if err != nil {
				fmt.Println(err)
				continue
			}
			hash, err := sendEther(c, account, toAddr, big.NewInt(1e18), nonce)
			if err != nil {
				fmt.Println(err)
				continue
			}
			fmt.Printf("send tx hash %s \n", hash)
		}
	}
}

type ExtAcc struct {
	Key  *ecdsa.PrivateKey
	addr common.Address
}

func sendEther(client *ethclient.Client, fromEO ExtAcc, toAddr common.Address, value *big.Int, nonce uint64) (common.Hash, error) {
	gasLimit := uint64(3e4)
	gasPrice := big.NewInt(params.GWei * 10)

	tx := types.NewTransaction(nonce, toAddr, value, gasLimit, gasPrice, nil)
	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainId), fromEO.Key)
	if err != nil {
		return common.Hash{}, err
	}
	err = client.SendTransaction(context.Background(), signedTx)
	if err != nil {
		return common.Hash{}, err
	}
	txhash := signedTx.Hash()
	return txhash, nil
}

func fromHexKey(hexkey string) (ExtAcc, error) {
	key, err := crypto.HexToECDSA(hexkey)
	if err != nil {
		return ExtAcc{}, err
	}
	pubKey := key.Public()
	pubKeyECDSA, ok := pubKey.(*ecdsa.PublicKey)
	if !ok {
		err = errors.New("publicKey is not of type *ecdsa.PublicKey")
		return ExtAcc{}, err
	}
	addr := crypto.PubkeyToAddress(*pubKeyECDSA)
	return ExtAcc{key, addr}, nil
}
