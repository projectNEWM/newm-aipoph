#!/usr/bin/env bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json

# coh script
coh_lock_script_path="../../contracts/coh_lock_contract.plutus"
coh_lock_script_address=$(${cli} address build --payment-script-file ${coh_lock_script_path} ${network})

# reference script
reference_script_path="../../contracts/reference_contract.plutus"
reference_script_address=$(${cli} address build --payment-script-file ${reference_script_path} ${network})

# collat
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# user
user_address=$(cat ../wallets/user-wallet/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/user-wallet/payment.vkey)

# the genesis pointer token information
tx_id_hash=$(jq -r '.tx_id_hash' ../../config.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../../config.json)
pointer_prefix=$(jq -r '.pointer_prefix' ../../config.json)
pointer_pid=$(cat ../../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

# coh token information
coh_policy_id=$(cardano-cli transaction policyid --script-file ../../contracts/coh_mint_contract.plutus)
coh_token_name=$(jq -r '.coh_token_name' ../../config.json)
coh_pointer_token=$(cat ../data/coh/coh-token.name)
coh_token="1 ${coh_policy_id}.${coh_token_name}"
coh_pointer_token="1 ${coh_policy_id}.${coh_pointer_tkn}"

# get coh script utxo
echo -e "\033[0;36m Gathering CoH UTxO Information  \033[0m"
${cli} query utxo \
    --address ${coh_lock_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${coh_lock_script_address} \033[0m \n";
.   exit;
fi
coh_lock_tx_in=$(jq -r 'keys[0]' ../tmp/script_utxo.json)
echo CoH UTxO: ${coh_lock_tx_in}

required_lovelace=$(jq -r 'to_entries[].value.value.lovelace' ../tmp/script_utxo.json)
coh_lock_script_out="${coh_lock_script_address} + ${required_lovelace} + ${coh_pointer_token} + ${coh_token}"
echo "CoH Verify OUTPUT: "${coh_lock_script_out}
#
# exit
#
echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${user_address} \
    --out-file ../tmp/user_utxo.json

TXNS=$(jq length ../tmp/user_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${user_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/user_utxo.json)
user_tx_in=${TXIN::-8}

# get refereence script utxo
echo -e "\033[0;36m Gathering Reference UTxO Information  \033[0m"
${cli} query utxo \
    --address ${reference_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${reference_script_address} \033[0m \n";
.   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" --arg policy_id "$pointer_pid" --arg token_name "$pointer_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
reference_tx_in=${TXIN::-8}

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
coh_lock_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-coh_lock_contract.plutus.signed )

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --change-address ${user_address} \
    --read-only-tx-in-reference ${reference_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${user_tx_in} \
    --tx-in ${coh_lock_tx_in} \
    --spending-tx-in-reference="${coh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/coh/verify-redeemer.json \
    --tx-out="${coh_lock_script_out}" \
    --tx-out-inline-datum-file ../data/coh/coh-datum.json \
    --required-signer-hash ${user_pkh} \
    --required-signer-hash ${collat_pkh} \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
FEE=${FEE[1]}
echo -e "\033[1;32m Fee: \033[0m" $FEE
#
exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../wallets/user-wallet/payment.skey \
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

cp ../data/oracle/updated-oracle-datum.json ../data/oracle/oracle-datum.json