#!/usr/bin/env bash
set -e

# SET UP VARS HERE
source .env

# reference contract
reference_script_path="../contracts/reference_contract.plutus"
reference_script_address=$(${cli} address build --payment-script-file ${reference_script_path} ${network})

# oracle script
oracle_script_path="../contracts/oracle_contract.plutus"
oracle_script_address=$(${cli} address build --payment-script-file ${oracle_script_path} ${network})

# vault
vault_script_path="../contracts/vault_contract.plutus"
vault_script_address=$(${cli} address build --payment-script-file ${vault_script_path} ${network})

# poh lock
poh_lock_script_path="../contracts/poh_lock_contract.plutus"
poh_lock_script_address=$(${cli} address build --payment-script-file ${poh_lock_script_path} ${network})

# coh lock
coh_lock_script_path="../contracts/coh_lock_contract.plutus"
coh_lock_script_address=$(${cli} address build --payment-script-file ${coh_lock_script_path} ${network})

# get current parameters
mkdir -p ./tmp
${cli} query protocol-parameters ${network} --out-file ./tmp/protocol.json
${cli} query tip ${network} | jq

# reference
echo -e "\033[1;35m Reference Contract Address: \033[0m" 
echo -e "\n \033[1;35m ${reference_script_address} \033[0m \n";
${cli} query utxo --address ${reference_script_address} ${network}
${cli} query utxo --address ${reference_script_address} ${network} --out-file ./tmp/current_reference.utxo

# oracle
echo -e "\033[1;35m Oracle Contract Address: \033[0m" 
echo -e "\n \033[1;35m ${oracle_script_address} \033[0m \n";
${cli} query utxo --address ${oracle_script_address} ${network}
${cli} query utxo --address ${oracle_script_address} ${network} --out-file ./tmp/current_oracle.utxo

# vault
echo -e "\033[1;35m Vault Contract Address: \033[0m" 
echo -e "\n \033[1;35m ${vault_script_address} \033[0m \n";
${cli} query utxo --address ${vault_script_address} ${network}
${cli} query utxo --address ${vault_script_address} ${network} --out-file ./tmp/current_vault.utxo

# poh lock
echo -e "\033[1;35m PoH Lock Contract Address: \033[0m" 
echo -e "\n \033[1;35m ${poh_lock_script_address} \033[0m \n";
${cli} query utxo --address ${poh_lock_script_address} ${network}
${cli} query utxo --address ${poh_lock_script_address} ${network} --out-file ./tmp/current_poh.utxo

# coh lock
echo -e "\033[1;35m CoH Lock Contract Address: \033[0m" 
echo -e "\n \033[1;35m ${coh_lock_script_address} \033[0m \n";
${cli} query utxo --address ${coh_lock_script_address} ${network}
${cli} query utxo --address ${coh_lock_script_address} ${network} --out-file ./tmp/current_coh.utxo

# Loop through each -wallet folder
for wallet_folder in wallets/*-wallet; do
    # Check if payment.addr file exists in the folder
    if [ -f "${wallet_folder}/payment.addr" ]; then
        addr=$(cat ${wallet_folder}/payment.addr)
        echo
        
        echo -e "\033[1;37m --------------------------------------------------------------------------------\033[0m"
        echo -e "\033[1;34m $wallet_folder\033[0m\n\n\033[1;32m $addr\033[0m"
        

        echo -e "\033[1;33m"
        # Run the cardano-cli command with the reference address and testnet magic
        ${cli} query utxo --address ${addr} ${network}
        ${cli} query utxo --address ${addr} ${network} --out-file ./tmp/"${addr}.json"

        baseLovelace=$(jq '[.. | objects | .lovelace] | add' ./tmp/"${addr}.json")
        echo -e "\033[0m"

        echo -e "\033[1;36m"
        ada=$(echo "scale = 6;${baseLovelace} / 1000000" | bc -l)
        echo -e "TOTAL ADA:" ${ada}
        echo -e "\033[0m"
    fi
done
