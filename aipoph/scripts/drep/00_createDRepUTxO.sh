#!/bin/bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json

# oracle script
drep_lock_script_path="../../contracts/drep_lock_contract.plutus"
drep_lock_script_address=$(${cli} address build --payment-script-file ${drep_lock_script_path} ${network})

# collat
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# drep
drep_address=$(cat ../wallets/drep-wallet/payment.addr)
drep_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/drep-wallet/payment.vkey)

# the utxo can hold 2^63 - 1
worst_case_token="9223372036854775807 0921c5652f6ba4c3311dd9a6231d2b93c56fca0766818742ba739f92.436f6e67726174756c6174696f6e732120596f7527726520612068756d616e2e"
min_utxo=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/drep/drep-lock-datum.json \
    --tx-out="${drep_lock_script_address} + 5000000 + ${worst_case_token}" | tr -dc '0-9')

drep_lock_script_out="${drep_lock_script_address} + ${min_utxo}"
echo "dRep Lock OUTPUT: "${drep_lock_script_out}
#
# exit
#
# get deleg utxo
echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
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

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --change-address ${drep_address} \
    --tx-in ${drep_tx_in} \
    --tx-out="${drep_lock_script_out}" \
    --tx-out-inline-datum-file ../data/drep/drep-lock-datum.json \
    --required-signer-hash ${drep_pkh} \
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
