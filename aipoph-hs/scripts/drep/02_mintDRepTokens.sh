#!/bin/bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json


# lock sale contract
drep_lock_script_path="../../contracts/drep_lock_contract.plutus"
drep_lock_script_address=$(${cli} address build --payment-script-file ${drep_lock_script_path} ${network})

# dao script
dao_script_path="../../contracts/dao_contract.plutus"
dao_script_address=$(${cli} address build --payment-script-file ${dao_script_path} ${network})

#
drep_address=$(cat ../wallets/drep-wallet/payment.addr)
drep_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/drep-wallet/payment.vkey)

#
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# the minting script policy
policy_id=$(cat ../../hashes/drep_mint.hash)
token_name="6452657020436f6e747269627574696f6e20546f6b656e"

if [[ $# -eq 0 ]] ; then
    echo -e "\n \033[0;31m Please Supply A Mint Amount \033[0m \n";
    exit
fi
if [[ ${1} -lt 0 ]] ; then
    echo -e "\n \033[0;31m Mint Amount Must Be Greater Than Zero \033[0m \n";
    exit
fi
mint_amt=${1}

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

# get script utxo
# asset to trade
# the locking token information
tx_id_hash=$(jq -r '.tx_id_hash' ../../start_info.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../../start_info.json)
pointer_prefix="5f6169706f70685f"
pointer_pid=$(cat ../../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

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

dao_pid=$(jq -r '.dao_pid' ../../start_info.json)
dao_tkn=$(jq -r '.dao_tkn' ../../start_info.json)

drep_lock_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/drep_script_utxo.json)
drep_lock_value=$(jq -r --arg policy_id "$dao_pid" --arg token_name "$dao_tkn" '.[].value[$policy_id][$token_name]' ../tmp/drep_script_utxo.json)

if [ "$drep_lock_value" = "null" ]; then
  drep_lock_value=0
else
  echo "Current dRep Amount:" ${drep_lock_value}
fi

total_drep_lock_value=$((${drep_lock_value} + ${mint_amt}))

# update the add_amt
variable=${mint_amt}; jq --argjson variable "$variable" '.fields[0].int=$variable' ../data/drep/mint-redeemer.json > ../data/drep/mint-redeemer-new.json
mv ../data/drep/mint-redeemer-new.json ../data/drep/mint-redeemer.json

script_address_out="${drep_lock_script_address} + ${drep_lock_lovelace_value} + ${total_drep_lock_value} ${dao_pid}.${dao_tkn}"
echo "DRep Lock OUTPUT:" ${script_address_out}

echo -e "\033[0;36m Gathering delegator UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${drep_address} \
    --out-file ../tmp/drep_utxo.json

TXNS=$(jq length ../tmp/drep_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${drep_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/drep_utxo.json)
drep_tx_in=${TXIN::-8}

tokens="${mint_amt} ${policy_id}.${token_name}"

min_utxo=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out="${drep_address} + 5000000 + ${tokens}" | tr -dc '0-9')
drep_address_out="${drep_address} + ${min_utxo} + ${tokens}"

echo "Delegator OUTPUT:" ${drep_address_out}
#
# exit
#
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
collat_utxo=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)

script_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/drep-mint-reference-utxo.signed)
lock_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/drep-lock-reference-utxo.signed)

# Add metadata to this build function for nfts with data
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --change-address ${drep_address} \
    --tx-in-collateral="${collat_utxo}" \
    --read-only-tx-in-reference ${dao_tx_in} \
    --tx-in ${drep_tx_in} \
    --tx-in ${drep_lock_tx_in} \
    --spending-tx-in-reference="${lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/drep/lock-redeemer.json \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ../data/drep/drep-lock-datum.json \
    --tx-out="${drep_address_out}" \
    --required-signer-hash ${collat_pkh} \
    --mint="${tokens}" \
    --mint-tx-in-reference="${script_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${policy_id}" \
    --mint-reference-tx-in-redeemer-file ../data/drep/mint-redeemer.json \
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