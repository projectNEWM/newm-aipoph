#!/bin/bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json

# oracle script
poh_lock_script_path="../../contracts/poh_lock_contract.plutus"
poh_lock_script_address=$(${cli} address build --payment-script-file ${poh_lock_script_path} ${network})

# user
user_address=$(cat ../wallets/user-wallet/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/user-wallet/payment.vkey)

# asset to trade
# the locking token information

# incentive, deposit, and poh token
worst_case_tokens="9223372036854775807 632e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162b.632e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162b00000000
+ 9223372036854775807 532e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c.532e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c00000000
+ 9223372036854775807 432e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162d.432e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c00000000"
min_utxo=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/poh/worst-case-poh-datum.json \
    --tx-out="${poh_lock_script_address} + 5000000 + ${worst_case_tokens}" | tr -dc '0-9')

# 3 ada for fees and 5 ada for the min utxo for the coh
required_lovelace=$((${min_utxo} + 5000000 + 5000000))
poh_lock_script_out="${poh_lock_script_address} + ${required_lovelace}"
echo "Proof of Humanity OUTPUT: "${poh_lock_script_out}
#
# exit
#
# get user utxo
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

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --change-address ${user_address} \
    --tx-in ${user_tx_in} \
    --tx-out="${poh_lock_script_out}" \
    --tx-out-inline-datum-file ../data/poh/initial-poh-datum.json \
    --required-signer-hash ${user_pkh} \
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
    --signing-key-file ../wallets/user-wallet/payment.skey \
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
