# AIPoPh Happy Path

This is a brief setup guide for the AIPoPh happy path. The happy path scripts require access to a full node, the cardano-cli, python3, jq, and sponge.

## Env Setup

The `.env` file inside the scripts folder is required for all scripts to function properly. It uses the selected network env files to pass in the path to the node socket and the path to the cardano-cli. The path file are located in the data folder under `path_to_socket.sh` and `path_to_cli.sh`. Update these files to the paths on the local machine.

## Wallet Setup

Use the `create_wallet.sh` script to auto create wallets inside the wallets folder.

```bash
./create_wallet.sh wallets/reference-wallet
./create_wallet.sh wallets/genesis-wallet
./create_wallet.sh wallets/collat-wallet
./create_wallet.sh wallets/user-wallet
./create_wallet.sh wallets/voter-wallet
./create_wallet.sh wallets/website-wallet
```

The voter wallet will hold all the action tokens, the user wallet will need enough ADA to pay for the transactions, the collateral wallet needs just 5 ADA, the reference wallet will need enough ADA to hold all the script refererences, and the website wallet is just used for signing. The genesis wallet needs just 5 ADA and that UTxO is used to build the contracts.

## Build Setup

The `config.json` file is required for a successful build. Place the action token information and genesis UTxO information inside of it and recompile the contracts using the `complete_build.sh` file. This will auto populate the genesis datum and contract folders with the new versions of the contracts.

## General Flow

The flow of the happy path is indicated by the number of the scripts. Initially, the script references need to be created then the genesis mint then the reference data petition all after compiling the contracts. After that each sub folder inside of scripts contain numbered scripts for interacting with each component. The main functionality is using the poh folder as this is the scripts required for starting, taking, ending, and verifying the test to produce a coh token.