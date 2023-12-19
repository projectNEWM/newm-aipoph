#!/bin/bash
set -e

# SET UP VARS HERE
source .env

# get params
${cli} query protocol-parameters ${network} --out-file tmp/protocol.json

# dao script
script_path="../contracts/dao_contract.plutus"
script_address=$(${cli} address build --payment-script-file ${script_path} ${network})

# collat
collat_address=$(cat wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file wallets/collat-wallet/payment.vkey)

# voter
voter_address=$(cat wallets/voter-wallet/payment.addr)
voter_pkh=$(${cli} address key-hash --payment-verification-key-file wallets/voter-wallet/payment.vkey)

# asset to trade
# the locking token information
tx_id_hash=$(jq -r '.tx_id_hash' ../start_info.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../start_info.json)
pointer_prefix="5f6169706f70685f"
pointer_pid=$(cat ../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")
asset="1 ${pointer_pid}.${pointer_tkn}"

current_min_utxo=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file tmp/protocol.json \
    --tx-out-inline-datum-file data/dao/dao-datum.json \
    --tx-out="${script_address} + 5000000 + ${asset}" | tr -dc '0-9')

updated_min_utxo=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file tmp/protocol.json \
    --tx-out-inline-datum-file data/dao/updated-dao-datum.json \
    --tx-out="${script_address} + 5000000 + ${asset}" | tr -dc '0-9')

difference=$((${updated_min_utxo} - ${current_min_utxo}))

if [ "$difference" -eq "0" ]; then
    echo "Minimum ADA is Constant"
elif [ "$difference" -lt "0" ]; then
    positive=$(( -1 * ${difference}))
    echo "Minimum ADA Decreasing by" ${positive}
    difference=$positive
else
    echo "Minimum ADA Increasing by" ${difference}
fi

# assume the min will always be the updated since updated can just be constant
min_utxo=${updated_min_utxo}

# update the difference
variable=${difference}; jq --argjson variable "$variable" '.fields[0].int=$variable' data/dao/petition-redeemer.json > data/dao/petition-redeemer-new.json
mv data/dao/petition-redeemer-new.json data/dao/petition-redeemer.json


dao_script_out="${script_address} + ${min_utxo} + ${asset}"
echo "Script OUTPUT: "${dao_script_out}
#
# exit
#
# get deleg utxo
echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${voter_address} \
    --out-file tmp/voter_utxo.json

TXNS=$(jq length tmp/voter_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${voter_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' tmp/voter_utxo.json)
voter_tx_in=${TXIN::-8}

# get script utxo
echo -e "\033[0;36m Gathering Script UTxO Information  \033[0m"
${cli} query utxo \
    --address ${script_address} \
    ${network} \
    --out-file tmp/script_utxo.json
TXNS=$(jq length tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${script_address} \033[0m \n";
.   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" --arg policy_id "$pointer_pid" --arg token_name "$pointer_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' tmp/script_utxo.json)
dao_tx_in=${TXIN::-8}

# collat info
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
collat_tx_in=$(jq -r 'keys[0]' tmp/collat_utxo.json)

# script reference utxo
dao_ref_utxo=$(${cli} transaction txid --tx-file tmp/dao-reference-utxo.signed )

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file tmp/tx.draft \
    --change-address ${voter_address} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${voter_tx_in} \
    --tx-in ${dao_tx_in} \
    --spending-tx-in-reference="${dao_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file data/dao/petition-redeemer.json \
    --tx-out="${dao_script_out}" \
    --tx-out-inline-datum-file data/dao/updated-dao-datum.json \
    --required-signer-hash ${voter_pkh} \
    --required-signer-hash ${collat_pkh} \
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
    --signing-key-file wallets/voter-wallet/payment.skey \
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

cp data/dao/updated-dao-datum.json data/dao/dao-datum.json