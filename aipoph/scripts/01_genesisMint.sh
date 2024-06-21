#!/usr/bin/env bash
set -e

# SET UP VARS HERE
source .env

# get params
${cli} query protocol-parameters ${network} --out-file tmp/protocol.json

# genesis contract
reference_script_path="../contracts/reference_contract.plutus"
reference_script_address=$(${cli} address build --payment-script-file ${reference_script_path} ${network})
reference_hash=$(cat ../hashes/reference.hash)

# bundle sale contract
genesis_script_path="../contracts/genesis_contract.plutus"

# genesis wallet
genesis_address=$(cat wallets/genesis-wallet/payment.addr)
genesis_pkh=$(${cli} address key-hash --payment-verification-key-file wallets/genesis-wallet/payment.vkey)

# collat wallet
collat_address=$(cat wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file wallets/collat-wallet/payment.vkey)

# return leftover ada address
change_address=$(jq -r '.change_address' ../config.json)

# the minting script policy
policy_id=$(cat ../hashes/genesis.hash)

echo -e "\033[0;36m Gathering Genesis UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${genesis_address} \
    --out-file tmp/genesis_utxo.json

TXNS=$(jq length tmp/genesis_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${genesis_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' tmp/genesis_utxo.json)
genesis_tx_in=${TXIN::-8}

echo "Genesis UTxO:" $genesis_tx_in

# # this is set in the reference data
petition_amount=$(jq -r '.thresholds.petition_threshold' ../reference_data.json)
jq --argjson petition_amount "$petition_amount" '.map[0].v.map[0].v.int=$petition_amount' data/genesis/genesis-datum.json  > data/genesis/genesis-datum-new.json
mv data/genesis/genesis-datum-new.json data/genesis/genesis-datum.json

jq --arg reference_hash "$reference_hash" '.map[1].v.map[0].v.bytes=$reference_hash' data/genesis/genesis-datum.json  > data/genesis/genesis-datum-new.json
mv data/genesis/genesis-datum-new.json data/genesis/genesis-datum.json

# the locking token information
tx_id_hash=$(jq -r '.tx_id_hash' ../config.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../config.json)

# the pointer token
pointer_prefix=$(jq -r '.pointer_prefix' ../config.json)
pointer_pid=$(cat ../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

mint_asset="1 ${pointer_pid}.${pointer_tkn}"
echo Minting: ${mint_asset}

utxo_value=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file tmp/protocol.json \
    --tx-out-inline-datum-file data/genesis/genesis-datum.json \
    --tx-out="${reference_script_address} + 5000000 + ${mint_asset}" | tr -dc '0-9')
reference_script_out="${reference_script_address} + ${utxo_value} + ${mint_asset}"

echo "Genesis OUTPUT:" ${reference_script_out}
#
# exit
#
echo -e "\033[0;36m Gathering Collateral UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${collat_address} \
    --out-file tmp/collat_utxo.json
TXNS=$(jq length tmp/collat_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${collat_address} \033[0m \n";
   exit;
fi
collat_utxo=$(jq -r 'keys[0]' tmp/collat_utxo.json)

genesis_ref_utxo=$(${cli} transaction txid --tx-file tmp/utxo-genesis_contract.plutus.signed )

# Add metadata to this build function for nfts with data
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file tmp/tx.draft \
    --change-address ${change_address} \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${genesis_tx_in} \
    --tx-out="${reference_script_out}" \
    --tx-out-inline-datum-file data/genesis/genesis-datum.json \
    --required-signer-hash ${collat_pkh} \
    --required-signer-hash ${genesis_pkh} \
    --mint="${mint_asset}" \
    --mint-tx-in-reference="${genesis_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${policy_id}" \
    --mint-reference-tx-in-redeemer-file data/genesis/genesis-redeemer.json \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
FEE=${FEE[1]}
echo -e "\033[1;32m Fee: \033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file wallets/genesis-wallet/payment.skey \
    --signing-key-file wallets/collat-wallet/payment.skey \
    --tx-body-file tmp/tx.draft \
    --out-file tmp/tx.signed \
    ${network}
#    
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} transaction submit \
    ${network} \
    --tx-file tmp/tx.signed

tx=$(cardano-cli transaction txid --tx-file tmp/tx.signed)
echo "Tx Hash:" $tx

cp data/genesis/genesis-datum.json data/reference/reference-datum.json