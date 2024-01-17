#!/bin/bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json

# drep lock script
drep_lock_script_path="../../contracts/drep_lock_contract.plutus"
drep_lock_script_address=$(${cli} address build --payment-script-file ${drep_lock_script_path} ${network})

# dao script
dao_script_path="../../contracts/dao_contract.plutus"
dao_script_address=$(${cli} address build --payment-script-file ${dao_script_path} ${network})

# collat
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# voter
voter_address=$(cat ../wallets/voter-wallet/payment.addr)
voter_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/voter-wallet/payment.vkey)

#
drep_address=$(cat ../wallets/drep-wallet/payment.addr)
drep_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/drep-wallet/payment.vkey)

# asset to trade
# the locking token information
tx_id_hash=$(jq -r '.tx_id_hash' ../../start_info.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../../start_info.json)
pointer_prefix="5f6169706f70685f"
pointer_pid=$(cat ../../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

#
# exit
#
# get deleg utxo
echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${voter_address} \
    --out-file ../tmp/voter_utxo.json

TXNS=$(jq length ../tmp/voter_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${voter_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/voter_utxo.json)
voter_tx_in=${TXIN::-8}

# get script utxo
echo -e "\033[0;36m Gathering DRep Lock Script UTxO Information  \033[0m"
${cli} query utxo \
    --address ${drep_lock_script_address} \
    ${network} \
    --out-file ../tmp/drep_script_utxo.json
TXNS=$(jq length ../tmp/drep_script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${drep_lock_script_address} \033[0m \n";
   exit;
fi
drep_lock_tx_in=$(jq -r 'keys[0]' ../tmp/drep_script_utxo.json)

dao_pid=$(jq -r '.dao_pid' ../../start_info.json)
dao_tkn=$(jq -r '.dao_tkn' ../../start_info.json)

drep_lock_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/drep_script_utxo.json)
drep_lock_value=$(jq -r --arg policy_id "$dao_pid" --arg token_name "$dao_tkn" '.[].value[$policy_id][$token_name]' ../tmp/drep_script_utxo.json)

if [ "$drep_lock_value" = "null" ]; then
  drep_lock_value=0
  exit
else
  echo "Current dRep Amount:" ${drep_lock_value}
fi
# Your numeric variable
if [ "$drep_lock_value" -eq 0 ]; then
    drep_lock_script_address_out="${drep_lock_script_address} + ${drep_lock_lovelace_value}"
else
    drep_lock_script_address_out="${drep_lock_script_address} + ${drep_lock_lovelace_value} + ${drep_lock_value} ${dao_pid}.${dao_tkn}"
fi
echo "dRep Lock OUTPUT: "${drep_lock_script_address_out}

# get script utxo
echo -e "\033[0;36m Gathering DAO UTxO Information  \033[0m"
${cli} query utxo \
    --address ${dao_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${dao_script_address} \033[0m \n";
.   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" --arg policy_id "$pointer_pid" --arg token_name "$pointer_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
dao_tx_in=${TXIN::-8}

dao_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/script_utxo.json)
dao_script_address_out="${dao_script_address} + ${dao_lovelace_value} + 1 ${pointer_pid}.${pointer_tkn}"
echo "DAO OUTPUT: "${dao_script_address_out}

# collat info
echo -e "\033[0;36m Gathering Collateral UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${collat_address} \
    --out-file ../tmp/collat_utxo.json

TXNS=$(jq length ../tmp/collat_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${collat_address} \033[0m \n";
   exit;
fi
collat_tx_in=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)

# script reference utxo
dao_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/dao-reference-utxo.signed )
drep_lock_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/drep-lock-reference-utxo.signed )


echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --change-address ${voter_address} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${voter_tx_in} \
    --tx-in ${drep_lock_tx_in} \
    --spending-tx-in-reference="${drep_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/drep/represent-redeemer.json \
    --tx-out="${drep_lock_script_address_out}" \
    --tx-out-inline-datum-file ../data/drep/drep-lock-datum.json \
    --tx-in ${dao_tx_in} \
    --spending-tx-in-reference="${dao_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/dao/petition-redeemer.json \
    --tx-out="${dao_script_address_out}" \
    --tx-out-inline-datum-file ../data/dao/updated-dao-datum.json \
    --required-signer-hash ${voter_pkh} \
    --required-signer-hash ${drep_pkh} \
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
    --signing-key-file ../wallets/voter-wallet/payment.skey \
    --signing-key-file ../wallets/drep-wallet/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
    --tx-body-file ../tmp/tx.draft \
    --out-file ../tmp/tx.signed \
    ${network}
#
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} transaction submit \
    ${network} \
    --tx-file ../tmp/tx.signed

tx=$(cardano-cli transaction txid --tx-file ../tmp/tx.signed)
echo "Tx Hash:" $tx

cp ../data/dao/updated-dao-datum.json ../data/dao/dao-datum.json