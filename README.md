## Exchange V1

### Prerequisites

**[Install foundry](https://book.getfoundry.sh/getting-started/installation)**

**[Get LINK and ETH on Sepolia](https://faucets.chain.link/sepolia)**

## Usage

### Build

```shell
forge build
```

### Run Documentation Server

```shell
forge doc --serve
```

### Test

```shell
forge test -vvv --gas-report
```

### Deploy Contracts on Sepolia Testnet

Please copy `.env.example` to `.env` and fill in the settings first.

```shell
forge script script/0001_DeployContracts.s.sol --fork-url sepolia --broadcast --slow --verify --private-key $PRIVATE_KEY
```

### Deployed Sepolia Contract Addresses

| Contract       | Address                                                                                                                       |
|----------------|-------------------------------------------------------------------------------------------------------------------------------|
| USDC           | [0x39c8c4E390f62EC07705b6d3BB2022d49555fFB2](https://sepolia.etherscan.io/address/0x39c8c4E390f62EC07705b6d3BB2022d49555fFB2) |
| Oracle         | [0xe13c1756c37f83Cd5F05eee3303ABa6790e3C4E2](https://sepolia.etherscan.io/address/0xe13c1756c37f83Cd5F05eee3303ABa6790e3C4E2) |
| Exchange Proxy | [0x56b6a92CDCa98a09bEf6fCfcaC1931aa49DaA760](https://sepolia.etherscan.io/address/0x56b6a92CDCa98a09bEf6fCfcaC1931aa49DaA760) |